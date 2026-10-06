import os
import re
import time
import random
import asyncio
import urllib.parse
from typing import List, Optional
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import httpx
from sentence_transformers import SentenceTransformer
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
from groq import Groq
from dotenv import load_dotenv
from duckduckgo_search import DDGS

# Load environment variables
load_dotenv()

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
if not GROQ_API_KEY:
    raise ValueError("GROQ_API_KEY environment variable is missing in backend/.env")

# Initialize FastAPI App
app = FastAPI(
    title="StarTrack Enterprise AI Engine",
    description="Vector RAG, Smart Human Entity Intelligence, Discover & Recommendations Backend",
    version="2.8.0"
)

# Enable CORS for Flutter & Web Clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global ML Instances
print("Initializing SentenceTransformer (all-MiniLM-L6-v2)...")
embedding_model = SentenceTransformer("all-MiniLM-L6-v2")
qdrant_client = QdrantClient(":memory:")
groq_client = Groq(api_key=GROQ_API_KEY)

HEADERS = {"User-Agent": "StarTrackAI-Engine/2.8 (contact@startrack.ai)"}

# Curated pool for randomized home feed / discover refreshes
DISCOVER_POOL = [
    "Tom Brady", "Christian Bale", "Augustus", "Gal Gadot", "Socrates", 
    "Elizabeth II", "Leonardo da Vinci", "Pablo Picasso", "Steven Spielberg", 
    "Robert De Niro", "Nelson Mandela", "Cleopatra", "Albert Einstein", 
    "Marie Curie", "Alexander the Great", "Marilyn Monroe", "Muhammad Ali", 
    "Julius Caesar", "Audrey Hepburn", "Isaac Newton", "Zendaya", 
    "Winston Churchill", "Cillian Murphy", "Frida Kahlo", "Bruce Lee", "Lionel Messi"
]


# -------------------------------------------------------------------
# Pydantic Schemas (Data Validation)
# -------------------------------------------------------------------
class RAGQueryRequest(BaseModel):
    entity_name: str = Field(..., example="Cillian Murphy")
    wikipedia_title: Optional[str] = Field(None, example="Cillian_Murphy")
    user_query: str = Field(..., example="What major awards has he won?")
    top_k: int = Field(3, ge=1, le=10)
    similarity_threshold: float = Field(0.25, ge=0.0, le=1.0, description="Minimum cosine similarity cutoff")


class ChunkMetadata(BaseModel):
    chunk_id: int
    text: str
    similarity_score: float


class PerformanceTelemetry(BaseModel):
    hydration_latency_ms: float
    vector_indexing_latency_ms: float
    vector_search_latency_ms: float
    llm_inference_latency_ms: float
    total_execution_ms: float
    avg_similarity_score: float


class RAGQueryResponse(BaseModel):
    entity: str
    answer: str
    image_urls: List[str]
    retrieved_chunks: List[ChunkMetadata]
    telemetry: PerformanceTelemetry


class PersonaSearchResult(BaseModel):
    title: str
    description: str
    wikidata_id: str
    image_url: Optional[str] = None


class RecommendRequest(BaseModel):
    liked_personas: List[str] = Field(..., example=["Christian Bale", "Robert De Niro"])
    limit: int = Field(6, ge=1, le=12)


# -------------------------------------------------------------------
# Helper Utilities
# -------------------------------------------------------------------
def sanitize_collection_name(name: str) -> str:
    """Sanitizes entity titles to conform with Qdrant collection naming rules."""
    cleaned = re.sub(r"[^a-zA-Z0-9_]", "_", name.lower())
    return f"entity_{cleaned}"[:63]


def chunk_text(text: str, chunk_size: int = 300, overlap: int = 50) -> List[str]:
    """Splits raw biography text into sliding window chunks with token overlap."""
    words = text.split()
    if not words:
        return []
    chunks = []
    for i in range(0, len(words), chunk_size - overlap):
        chunk = " ".join(words[i : i + chunk_size])
        if len(chunk.strip()) > 0:
            chunks.append(chunk)
    return chunks


async def fetch_wikipedia_text(title: str) -> str:
    """Fetches purely the biographical text from Wikipedia."""
    clean_title = title.replace(" ", "_").strip()
    
    async with httpx.AsyncClient(follow_redirects=True, timeout=10.0) as client:
        # Layer 1: REST API
        rest_url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{clean_title}"
        try:
            res = await client.get(rest_url, headers=HEADERS)
            if res.status_code == 200:
                extract = res.json().get("extract", "")
                if len(extract) > 100:
                    return extract
        except Exception:
            pass 

        # Layer 2: Action API Fallback
        action_url = "https://en.wikipedia.org/w/api.php"
        params = {
            "action": "query", "prop": "extracts", "exintro": True, 
            "explaintext": True, "titles": clean_title, "format": "json", "redirects": 1
        }
        res_action = await client.get(action_url, params=params, headers=HEADERS)
        if res_action.status_code == 200:
            pages = res_action.json().get("query", {}).get("pages", {})
            for page_id, page_data in pages.items():
                if page_id != "-1" and "extract" in page_data:
                    return page_data["extract"].strip()

    raise HTTPException(status_code=404, detail=f"Could not retrieve Wikipedia text for '{title}'.")


def fetch_free_images_sync(query: str, num_images: int = 6) -> List[str]:
    """Fetches high-quality web images via DuckDuckGo as a reliable fallback."""
    try:
        search_query = f"{query} person portrait photo"
        results = DDGS().images(
            keywords=search_query,
            region="wt-wt",
            safesearch="moderate",
            max_results=num_images
        )
        return [item.get("image") for item in results if item.get("image")]
    except Exception as e:
        print(f"DuckDuckGo fallback image search failed: {e}")
        return []


async def fetch_web_images(query: str, num_images: int = 6) -> List[str]:
    """Async wrapper for DuckDuckGo image search."""
    return await asyncio.to_thread(fetch_free_images_sync, query, num_images)


async def build_single_persona_card(client: httpx.AsyncClient, name: str) -> Optional[PersonaSearchResult]:
    """Helper utility to build a full persona card with image thumbnail for home/discover feeds."""
    try:
        opensearch_params = {"action": "opensearch", "search": name, "limit": 2, "namespace": 0, "redirects": "resolve", "format": "json"}
        res = await client.get("https://en.wikipedia.org/w/api.php", params=opensearch_params, headers=HEADERS)
        titles = res.json()[1] if len(res.json()) >= 2 else []
        title_to_check = titles[0] if titles else name

        wd_params = {"action": "wbgetentities", "sites": "enwiki", "titles": title_to_check, "props": "claims|labels|descriptions", "languages": "en", "format": "json"}
        ent_res = await client.get("https://www.wikidata.org/w/api.php", params=wd_params, headers=HEADERS)
        entities = ent_res.json().get("entities", {})
        
        for qid, entity in entities.items():
            if qid == "-1": continue
            claims = entity.get("claims", {})
            
            is_human = any(stmt.get("mainsnak", {}).get("datavalue", {}).get("value", {}).get("id") == "Q5" for stmt in claims.get("P31", []))
            if is_human:
                image_url = None
                if "P18" in claims:
                    try:
                        filename = claims["P18"][0]["mainsnak"]["datavalue"]["value"]
                        image_url = urllib.parse.quote(f"https://commons.wikimedia.org/wiki/Special:FilePath/{filename.replace(' ', '_')}", safe=":/%#?=@[]!$&'()*+,;")
                    except Exception:
                        pass
                
                if not image_url:
                    fallback = await fetch_web_images(title_to_check, num_images=1)
                    if fallback:
                        image_url = fallback[0]
                
                return PersonaSearchResult(
                    title=entity.get("labels", {}).get("en", {}).get("value", title_to_check),
                    description=entity.get("descriptions", {}).get("en", {}).get("value", "Known persona"),
                    wikidata_id=qid,
                    image_url=image_url
                )
    except Exception:
        pass
    return None


async def verify_human_and_fetch_images(entity_name: str, limit: int = 6) -> tuple[str, List[str]]:
    """
    SMART HUMAN FILTER WITH REDIRECT RESOLUTION:
    1. Uses Wikipedia OpenSearch to smartly resolve aliases (e.g. "messi" -> "Lionel Messi").
    2. Queries Wikidata to verify the resolved title is a HUMAN (P31 == Q5).
    3. Retrieves official Wikipedia title + high-res Commons & Web images.
    """
    image_urls: List[str] = []
    official_wikipedia_title = entity_name
    selected_claims = None
    human_found = False

    async with httpx.AsyncClient(follow_redirects=True, timeout=10.0) as client:
        opensearch_params = {
            "action": "opensearch",
            "search": entity_name,
            "limit": 5,
            "namespace": 0,
            "redirects": "resolve",
            "format": "json"
        }
        res = await client.get("https://en.wikipedia.org/w/api.php", params=opensearch_params, headers=HEADERS)
        data = res.json()
        titles = data[1] if len(data) >= 2 else []

        if titles:
            wd_params = {
                "action": "wbgetentities",
                "sites": "enwiki",
                "titles": "|".join(titles),
                "props": "claims|sitelinks",
                "format": "json"
            }
            ent_res = await client.get("https://www.wikidata.org/w/api.php", params=wd_params, headers=HEADERS)
            entities_data = ent_res.json().get("entities", {})

            title_to_entity = {}
            for qid, entity in entities_data.items():
                if qid == "-1": continue
                enwiki_title = entity.get("sitelinks", {}).get("enwiki", {}).get("title")
                if enwiki_title:
                    title_to_entity[enwiki_title] = (qid, entity)

            for title in titles:
                if title in title_to_entity:
                    qid, entity = title_to_entity[title]
                    claims = entity.get("claims", {})
                    
                    if "P31" in claims:
                        for statement in claims["P31"]:
                            try:
                                if statement["mainsnak"]["datavalue"]["value"]["id"] == "Q5":
                                    human_found = True
                                    selected_claims = claims
                                    official_wikipedia_title = title
                                    break
                            except (KeyError, TypeError):
                                pass
                    if human_found:
                        break

        if not human_found:
            search_url = "https://www.wikidata.org/w/api.php"
            search_params = {"action": "wbsearchentities", "search": entity_name, "language": "en", "format": "json", "limit": 5}
            res = await client.get(search_url, params=search_params, headers=HEADERS)
            search_results = res.json().get("search", [])
            
            for item in search_results:
                candidate_qid = item.get("id")
                if not candidate_qid: continue
                
                entity_url = f"https://www.wikidata.org/wiki/Special:EntityData/{candidate_qid}.json"
                entity_res = await client.get(entity_url, headers=HEADERS)
                if entity_res.status_code != 200: continue
                
                entity_data = entity_res.json()
                claims = entity_data.get("entities", {}).get(candidate_qid, {}).get("claims", {})
                
                if "P31" in claims:
                    for statement in claims["P31"]:
                        try:
                            if statement["mainsnak"]["datavalue"]["value"]["id"] == "Q5":
                                human_found = True
                                selected_claims = claims
                                sitelinks = entity_data.get("entities", {}).get(candidate_qid, {}).get("sitelinks", {})
                                if "enwiki" in sitelinks:
                                    official_wikipedia_title = sitelinks["enwiki"].get("title", entity_name)
                                break
                        except (KeyError, TypeError): pass
                
                if human_found: break

        if not human_found or not selected_claims:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"'{entity_name}' is not a human persona. StarTrack strictly indexes human entities."
            )

        try:
            commons_category = None
            if "P373" in selected_claims:
                try:
                    commons_category = selected_claims["P373"][0]["mainsnak"]["datavalue"]["value"]
                except (KeyError, IndexError, TypeError):
                    pass

            if commons_category:
                cat_title = f"Category:{commons_category}"
                commons_api = "https://commons.wikimedia.org/w/api.php"
                commons_params = {
                    "action": "query",
                    "generator": "categorymembers",
                    "gcmtitle": cat_title,
                    "gcmtype": "file",
                    "gcmlimit": limit * 2,
                    "prop": "imageinfo",
                    "iiprop": "url",
                    "format": "json"
                }
                comm_res = await client.get(commons_api, params=commons_params, headers=HEADERS)
                if comm_res.status_code == 200:
                    comm_data = comm_res.json()
                    pages = comm_data.get("query", {}).get("pages", {})
                    
                    for page_info in pages.values():
                        if "imageinfo" in page_info:
                            img_url = page_info["imageinfo"][0].get("url")
                            if img_url and img_url.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
                                sanitized_url = urllib.parse.quote(img_url, safe=":/%#?=@[]!$&'()*+,;")
                                if sanitized_url not in image_urls:
                                    image_urls.append(sanitized_url)

            if "P18" in selected_claims:
                try:
                    filename = selected_claims["P18"][0]["mainsnak"]["datavalue"]["value"]
                    encoded_filename = filename.replace(" ", "_")
                    p18_raw_url = f"https://commons.wikimedia.org/wiki/Special:FilePath/{encoded_filename}"
                    sanitized_p18 = urllib.parse.quote(p18_raw_url, safe=":/%#?=@[]!$&'()*+,;")
                    if sanitized_p18 not in image_urls:
                        image_urls.insert(0, sanitized_p18)
                except (KeyError, IndexError, TypeError):
                    pass

        except Exception as e:
            print(f"Commons image extraction warning: {e}")

    if len(image_urls) < limit:
        needed = limit - len(image_urls)
        try:
            fallback_images = await fetch_web_images(official_wikipedia_title, num_images=needed)
            for url in fallback_images:
                if url not in image_urls:
                    image_urls.append(url)
        except Exception as e:
            print(f"DuckDuckGo fallback warning: {e}")

    return official_wikipedia_title, image_urls[:limit]


# -------------------------------------------------------------------
# Endpoints
# -------------------------------------------------------------------
@app.get("/health", status_code=status.HTTP_200_OK)
def health_check():
    return {
        "status": "healthy",
        "engine": "StarTrack RAG Microservice",
        "embedding_model": "all-MiniLM-L6-v2",
        "vector_store": "Qdrant (In-Memory)",
        "llm_provider": "Groq (openai/gpt-oss-120b)",
    }


@app.get("/api/v1/personas/discover", response_model=List[PersonaSearchResult])
async def discover_personas(limit: int = 6):
    """Returns a randomized assortment of diverse personas for the Home Feed/Refresh."""
    selected_names = random.sample(DISCOVER_POOL, min(limit, len(DISCOVER_POOL)))
    async with httpx.AsyncClient(timeout=15.0) as client:
        tasks = [build_single_persona_card(client, name) for name in selected_names]
        results = await asyncio.gather(*tasks)
    return [res for res in results if res is not None]


@app.post("/api/v1/personas/recommend", response_model=List[PersonaSearchResult])
async def recommend_personas(payload: RecommendRequest):
    """Uses Groq LLM to generate intelligent recommendations based on user's saved/liked personas."""
    if not payload.liked_personas:
        return await discover_personas(payload.limit)

    prompt = f"The user likes these historical figures and celebrities: {', '.join(payload.liked_personas)}. Recommend {payload.limit} similar famous people. Return ONLY a comma-separated list of their names. Do not include the original names or any other text."
    
    try:
        completion = groq_client.chat.completions.create(
            model="llama3-8b-8192", 
            messages=[{"role": "user", "content": prompt}],
            temperature=0.7, max_tokens=50
        )
        llm_response = completion.choices[0].message.content
        suggested_names = [name.strip() for name in llm_response.split(",") if name.strip()]
    except Exception as e:
        print(f"Groq recommendation failed: {e}")
        return await discover_personas(payload.limit)

    async with httpx.AsyncClient(timeout=15.0) as client:
        tasks = [build_single_persona_card(client, name) for name in suggested_names[:payload.limit]]
        results = await asyncio.gather(*tasks)
    
    valid_results = [res for res in results if res is not None]
    if len(valid_results) < payload.limit:
        fallback = await discover_personas(payload.limit - len(valid_results))
        valid_results.extend(fallback)

    return valid_results[:payload.limit]


@app.get("/api/v1/search/personas", response_model=List[PersonaSearchResult])
async def search_human_personas(q: str):
    """
    Smart Search Endpoint. Resolves partial inputs/slang via Wikipedia OpenSearch redirects
    and strictly validates them as human personas with image thumbnails.
    """
    human_results = []
    
    async with httpx.AsyncClient(timeout=10.0) as client:
        opensearch_params = {
            "action": "opensearch",
            "search": q,
            "limit": 10,
            "namespace": 0,
            "redirects": "resolve",
            "format": "json"
        }
        res = await client.get("https://en.wikipedia.org/w/api.php", params=opensearch_params, headers=HEADERS)
        data = res.json()
        titles = data[1] if len(data) >= 2 else []

        if titles:
            wd_params = {
                "action": "wbgetentities",
                "sites": "enwiki",
                "titles": "|".join(titles),
                "props": "claims|labels|descriptions|sitelinks",
                "languages": "en",
                "format": "json"
            }
            ent_res = await client.get("https://www.wikidata.org/w/api.php", params=wd_params, headers=HEADERS)
            entities_data = ent_res.json().get("entities", {})
            
            title_to_entity = {}
            for qid, entity in entities_data.items():
                if qid == "-1": continue
                enwiki_title = entity.get("sitelinks", {}).get("enwiki", {}).get("title")
                if enwiki_title:
                    title_to_entity[enwiki_title] = (qid, entity)

            for title in titles:
                if title not in title_to_entity: continue
                qid, entity = title_to_entity[title]
                claims = entity.get("claims", {})
                
                is_human = False
                if "P31" in claims:
                    for statement in claims["P31"]:
                        try:
                            if statement["mainsnak"]["datavalue"]["value"]["id"] == "Q5":
                                is_human = True
                                break
                        except Exception:
                            pass
                        
                if is_human:
                    image_url = None
                    if "P18" in claims:
                        try:
                            filename = claims["P18"][0]["mainsnak"]["datavalue"]["value"]
                            image_url = urllib.parse.quote(f"https://commons.wikimedia.org/wiki/Special:FilePath/{filename.replace(' ', '_')}", safe=":/%#?=@[]!$&'()*+,;")
                        except Exception:
                            pass
                    
                    label = entity.get("labels", {}).get("en", {}).get("value", title)
                    description = entity.get("descriptions", {}).get("en", {}).get("value", "Known persona")
                    
                    human_results.append(PersonaSearchResult(title=label, description=description, wikidata_id=qid, image_url=image_url))
                    if len(human_results) >= 6: break

        if not human_results:
            search_params = {"action": "wbsearchentities", "search": q, "language": "en", "format": "json", "limit": 10}
            res = await client.get("https://www.wikidata.org/w/api.php", params=search_params, headers=HEADERS)
            results = res.json().get("search", [])
            
            qids = [item["id"] for item in results if "id" in item]
            if qids:
                entities_params = {"action": "wbgetentities", "ids": "|".join(qids), "props": "claims", "format": "json"}
                ent_res = await client.get("https://www.wikidata.org/w/api.php", params=entities_params, headers=HEADERS)
                entities_data = ent_res.json().get("entities", {})
                
                for item in results:
                    qid = item["id"]
                    claims = entities_data.get(qid, {}).get("claims", {})
                    
                    is_human = False
                    if "P31" in claims:
                        for statement in claims["P31"]:
                            try:
                                if statement["mainsnak"]["datavalue"]["value"]["id"] == "Q5":
                                    is_human = True
                                    break
                            except Exception:
                                pass
                            
                    if is_human:
                        image_url = None
                        if "P18" in claims:
                            try:
                                filename = claims["P18"][0]["mainsnak"]["datavalue"]["value"]
                                image_url = urllib.parse.quote(f"https://commons.wikimedia.org/wiki/Special:FilePath/{filename.replace(' ', '_')}", safe=":/%#?=@[]!$&'()*+,;")
                            except Exception:
                                pass
                        
                        human_results.append(PersonaSearchResult(
                            title=item.get("label", ""),
                            description=item.get("description", "Known persona"),
                            wikidata_id=qid,
                            image_url=image_url
                        ))
                        if len(human_results) >= 6: break

        async def fetch_and_set_fallback(res_item: PersonaSearchResult):
            if not res_item.image_url:
                try:
                    fallback = await fetch_web_images(res_item.title, num_images=1)
                    if fallback: res_item.image_url = fallback[0]
                except Exception:
                    pass

        await asyncio.gather(*(fetch_and_set_fallback(res_item) for res_item in human_results))
        return human_results


@app.post("/api/v1/rag/query", response_model=RAGQueryResponse)
async def perform_rag_query(payload: RAGQueryRequest):
    total_start = time.time()

    # Step 1: Strict Human Verification & Image Hydration
    t0 = time.time()
    verified_title, entity_images = await verify_human_and_fetch_images(payload.entity_name, limit=6)
    raw_text = await fetch_wikipedia_text(verified_title)
    hydration_ms = (time.time() - t0) * 1000

    # Step 2: Chunking & Vector Indexing
    t1 = time.time()
    chunks = chunk_text(raw_text, chunk_size=300, overlap=50)
    if not chunks:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Failed to generate text chunks from retrieved content.",
        )

    embeddings = embedding_model.encode(chunks, convert_to_numpy=True)
    collection_name = sanitize_collection_name(verified_title)
    vector_dim = embeddings.shape[1]

    qdrant_client.recreate_collection(
        collection_name=collection_name,
        vectors_config=VectorParams(size=vector_dim, distance=Distance.COSINE),
    )

    points = [
        PointStruct(id=idx, vector=vector.tolist(), payload={"text": chunk})
        for idx, (chunk, vector) in enumerate(zip(chunks, embeddings))
    ]
    qdrant_client.upsert(collection_name=collection_name, points=points)
    indexing_ms = (time.time() - t1) * 1000

    # Step 3: Cosine Similarity Vector Search
    t2 = time.time()
    query_vector = embedding_model.encode(payload.user_query).tolist()

    search_results = qdrant_client.query_points(
        collection_name=collection_name,
        query=query_vector,
        limit=payload.top_k,
    ).points

    filtered_chunks = [
        res for res in search_results if res.score >= payload.similarity_threshold
    ]
    final_results = filtered_chunks if filtered_chunks else search_results

    retrieved_chunks = [
        ChunkMetadata(
            chunk_id=res.id,
            text=res.payload["text"],
            similarity_score=round(res.score, 4),
        )
        for res in final_results
    ]

    avg_score = (
        round(sum(c.similarity_score for c in retrieved_chunks) / len(retrieved_chunks), 4)
        if retrieved_chunks
        else 0.0
    )
    search_ms = (time.time() - t2) * 1000

    # Step 4: Grounded LLM Generation via Groq
    t3 = time.time()
    context_blocks = "\n\n".join([f"[Source Chunk {c.chunk_id}]: {c.text}" for c in retrieved_chunks])

    system_prompt = (
        f"You are the StarTrack AI Entity Assistant. "
        f"Answer questions accurately using ONLY the provided facts about {payload.entity_name}. "
        f"If the answer cannot be determined from the context, clearly state that information is unavailable."
    )
    user_prompt = f"Context:\n{context_blocks}\n\nQuestion: {payload.user_query}"

    try:
        completion = groq_client.chat.completions.create(
            model="openai/gpt-oss-120b", 
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.2,
            max_tokens=600,
        )
        ai_answer = completion.choices[0].message.content
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Groq API Inference failed: {str(e)}",
        )
    llm_ms = (time.time() - t3) * 1000
    total_ms = (time.time() - total_start) * 1000

    telemetry = PerformanceTelemetry(
        hydration_latency_ms=round(hydration_ms, 2),
        vector_indexing_latency_ms=round(indexing_ms, 2),
        vector_search_latency_ms=round(search_ms, 2),
        llm_inference_latency_ms=round(llm_ms, 2),
        total_execution_ms=round(total_ms, 2),
        avg_similarity_score=avg_score,
    )

    return RAGQueryResponse(
        entity=payload.entity_name,
        answer=ai_answer,
        image_urls=entity_images,
        retrieved_chunks=retrieved_chunks,
        telemetry=telemetry,
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)