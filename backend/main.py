import os
import re
import json
import time
import random
import asyncio
import hashlib
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

# Load environment variables from backend directory and current directory
_backend_dir = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(_backend_dir, ".env"))
load_dotenv()

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
if not GROQ_API_KEY:
    raise ValueError("GROQ_API_KEY environment variable is missing in backend/.env")

# Initialize FastAPI App
app = FastAPI(
    title="StarTrack Enterprise AI Engine",
    description="Vector RAG, Typo-Tolerant Entity Search, Infinite Discover & Recommendations",
    version="3.1.0"
)

# Enable CORS for Flutter & Web Clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "StarTrack Enterprise AI Engine"}

# Global ML Instances
print("Initializing SentenceTransformer (all-MiniLM-L6-v2)...")
embedding_model = SentenceTransformer("all-MiniLM-L6-v2")
qdrant_client = QdrantClient(":memory:")
groq_client = Groq(api_key=GROQ_API_KEY)

HEADERS = {"User-Agent": "StarTrackAI-Engine/3.1 (contact@startrack.ai)"}

# Massively expanded pool for infinite scroll
DISCOVER_POOL = [
    "Tom Brady", "Christian Bale", "Augustus", "Gal Gadot", "Socrates", 
    "Elizabeth II", "Leonardo da Vinci", "Pablo Picasso", "Steven Spielberg", 
    "Robert De Niro", "Nelson Mandela", "Cleopatra", "Albert Einstein", 
    "Marie Curie", "Alexander the Great", "Marilyn Monroe", "Muhammad Ali", 
    "Julius Caesar", "Audrey Hepburn", "Isaac Newton", "Zendaya", 
    "Winston Churchill", "Cillian Murphy", "Frida Kahlo", "Bruce Lee", "Lionel Messi",
    "Keanu Reeves", "Scarlett Johansson", "Nikola Tesla", "Vincent van Gogh",
    "Martin Luther King Jr.", "Mahatma Gandhi", "Rosa Parks", "Amelia Earhart", 
    "William Shakespeare", "Wolfgang Amadeus Mozart", "Ludwig van Beethoven", "Aristotle", 
    "Plato", "Joan of Arc", "Genghis Khan", "George Washington", "Abraham Lincoln", 
    "Thomas Edison", "Henry Ford", "Walt Disney", "Charlie Chaplin", "Elvis Presley", 
    "Michael Jackson", "Madonna", "John Lennon", "Paul McCartney", "David Bowie", 
    "Freddie Mercury", "Queen Victoria", "Charles Darwin", "Stephen Hawking", 
    "Alan Turing", "Steve Jobs", "Bill Gates", "Mark Zuckerberg", "Elon Musk", 
    "Neil Armstrong", "Buzz Aldrin", "Yuri Gagarin", "Jackie Robinson", "Babe Ruth", 
    "Michael Jordan", "Serena Williams", "Roger Federer", "Cristiano Ronaldo", 
    "Pele", "Diego Maradona", "Usain Bolt", "Simone Biles", "Malala Yousafzai", 
    "Mother Teresa", "Dalai Lama", "Pope Francis", "Kofi Annan", "Margaret Thatcher", 
    "Angela Merkel", "Indira Gandhi", "J.R.R. Tolkien", "J.K. Rowling", "Stephen King", 
    "Agatha Christie", "Ernest Hemingway", "Mark Twain", "Charles Dickens", 
    "Jane Austen", "Edgar Allan Poe", "Virginia Woolf", "Sylvia Plath", "Maya Angelou"
]


# -------------------------------------------------------------------
# Pydantic Schemas (Data Validation)
# -------------------------------------------------------------------
class OverviewCard(BaseModel):
    title: str
    content: str
    category: Optional[str] = None
    subtitle: Optional[str] = None
    icon: Optional[str] = "sparkles"
    key_points: Optional[List[str]] = None


class RAGQueryRequest(BaseModel):
    entity_name: str = Field(..., example="Cillian Murphy")
    wikipedia_title: Optional[str] = Field(None, example="Cillian_Murphy")
    user_query: str = Field(..., example="What major awards has he won?")
    top_k: int = Field(3, ge=1, le=10)
    similarity_threshold: float = Field(0.25, ge=0.0, le=1.0, description="Minimum cosine similarity cutoff")
    format_type: Optional[str] = Field("standard", description="'cards' for concise swipeable cards, 'chat' or 'standard' for full in-depth response")


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
    overview_cards: Optional[List[OverviewCard]] = None
    labels: List[str] = Field(default_factory=list)


class PersonaSearchResult(BaseModel):
    title: str
    description: str
    wikidata_id: str
    image_url: Optional[str] = None
    labels: List[str] = Field(default_factory=list)


WIKIDATA_QID_LABELS: dict[str, str] = {
    # Countries (P27 / P495)
    "Q414": "Argentina", "Q142": "France", "Q30": "United States", "Q145": "United Kingdom",
    "Q29": "Spain", "Q38": "Italy", "Q183": "Germany", "Q45": "Portugal", "Q155": "Brazil",
    "Q36": "Poland", "Q79": "Egypt", "Q17": "Japan", "Q148": "China", "Q159": "Russia",
    "Q668": "India", "Q96": "Mexico", "Q114": "Kenya", "Q258": "South Africa", "Q22": "Scotland", "Q27": "Ireland",
    "Q16": "Canada", "Q408": "Australia", "Q55": "Netherlands", "Q34": "Sweden", "Q801": "Israel",
    # Broad Super-Categories & Occupations (P106)
    "Q2066131": "Athlete", "Q937857": "Football Player", "Q10833314": "Football Player",
    "Q10871364": "Basketball Player", "Q11514315": "Tennis Player",
    "Q11513337": "Boxer", "Q1078733": "Swimmer", "Q11514330": "Formula One Driver",
    "Q901": "Scientist", "Q1622272": "Scientist", "Q169470": "Theoretical Physicist",
    "Q593644": "Physicist", "Q864503": "Chemist", "Q170790": "Mathematician",
    "Q11063": "Astronomer", "Q82594": "Computer Scientist", "Q482980": "Author", "Q36180": "Writer",
    "Q49757": "Poet", "Q214917": "Playwright", "Q33999": "Actor", "Q2526255": "Film Director",
    "Q28389": "Screenwriter", "Q177220": "Singer", "Q36834": "Composer", "Q639669": "Musician",
    "Q483501": "Artist", "Q1028181": "Painter", "Q128161": "Sculptor", "Q42973": "Architect",
    "Q82955": "Politician", "Q30461": "President", "Q14211": "Prime Minister", "Q116": "Monarch",
    "Q39018": "Emperor", "Q193391": "Diplomat", "Q108005": "Philosopher", "Q188094": "Economist",
    "Q201788": "Historian", "Q11631": "Astronaut", "Q205375": "Inventor", "Q81096": "Engineer",
    "Q43845": "Entrepreneur", "Q84": "General", "Q47064": "Military Commander",
    # Awards & Accolades (P166)
    "Q7191": "Nobel Laureate", "Q38104": "Nobel Laureate", "Q44585": "Nobel Laureate",
    "Q37922": "Nobel Peace Laureate", "Q80061": "Nobel Laureate",
    "Q166177": "Ballon d'Or Winner", "Q19317": "World Cup Champion", "Q19020": "Academy Award Winner",
    "Q108047": "Academy Award Winner", "Q103618": "Academy Award Winner", "Q41254": "Grammy Winner",
    "Q131520": "Olympic Medalist", "Q8537": "Golden Globe Winner", "Q104670": "Super Bowl Champion",
    # Disciplines & Fields (P101 / P136)
    "Q413": "Physics", "Q2329": "Chemistry", "Q395": "Mathematics", "Q333": "Astronomy",
    "Q11190": "Medicine", "Q5891": "Philosophy", "Q11424": "Cinema & Film", "Q638": "Music",
    "Q8242": "Literature", "Q11660": "Artificial Intelligence", "Q5340": "Sports",
    "Q11019": "Technology", "Q944": "Quantum Mechanics",
    # Characters, Universes & Meta (P31 / P1441 / P178)
    "Q9525": "Video Game Character", "Q1572434": "Fictional Character", "Q1056584": "Superhero",
    "Q37248": "SEGA", "Q8093": "Nintendo", "Q11400": "Marvel", "Q292467": "DC Comics",
}

# Comprehensive Super-Category and Domain Ontology (Broad and all-encompassing)
COMPREHENSIVE_SUPER_CATEGORIES: dict[str, tuple[str, str]] = {
    # Sports & Athletics -> (Super-Category, Domain)
    "football player": ("Athlete", "Sports"),
    "association football player": ("Athlete", "Sports"),
    "footballer": ("Athlete", "Sports"),
    "soccer": ("Athlete", "Sports"),
    "basketball player": ("Athlete", "Sports"),
    "basketball": ("Athlete", "Sports"),
    "tennis player": ("Athlete", "Sports"),
    "tennis": ("Athlete", "Sports"),
    "athlete": ("Athlete", "Sports"),
    "swimmer": ("Athlete", "Sports"),
    "boxer": ("Athlete", "Sports"),
    "boxing": ("Athlete", "Sports"),
    "martial artist": ("Athlete", "Sports"),
    "racing driver": ("Athlete", "Sports"),
    "formula one driver": ("Athlete", "Sports"),
    "cyclist": ("Athlete", "Sports"),
    "baseball player": ("Athlete", "Sports"),
    "american football player": ("Athlete", "Sports"),
    "quarterback": ("Athlete", "Sports"),
    "golfer": ("Athlete", "Sports"),
    "cricketer": ("Athlete", "Sports"),
    "gymnast": ("Athlete", "Sports"),

    # Science & Academia
    "physicist": ("Scientist", "Physics"),
    "theoretical physicist": ("Scientist", "Physics"),
    "astrophysicist": ("Scientist", "Physics"),
    "chemist": ("Scientist", "Chemistry"),
    "biologist": ("Scientist", "Biology"),
    "mathematician": ("Scientist", "Mathematics"),
    "astronomer": ("Scientist", "Astronomy"),
    "scientist": ("Scientist", "Science"),
    "computer scientist": ("Scientist", "Technology"),
    "neuroscientist": ("Scientist", "Medicine"),
    "geneticist": ("Scientist", "Biology"),
    "geologist": ("Scientist", "Science"),
    "physician": ("Scientist", "Medicine"),
    "polymath": ("Polymath", "Science"),

    # Cinema & Film
    "actor": ("Actor", "Cinema & Film"),
    "actress": ("Actor", "Cinema & Film"),
    "comedian": ("Actor", "Cinema & Film"),
    "voice actor": ("Actor", "Cinema & Film"),
    "film director": ("Film Director", "Cinema & Film"),
    "director": ("Film Director", "Cinema & Film"),
    "filmmaker": ("Filmmaker", "Cinema & Film"),
    "screenwriter": ("Screenwriter", "Cinema & Film"),
    "film producer": ("Film Producer", "Cinema & Film"),

    # Music & Audio Arts
    "musician": ("Musician", "Music"),
    "singer": ("Musician", "Music"),
    "songwriter": ("Musician", "Music"),
    "composer": ("Musician", "Music"),
    "pianist": ("Musician", "Music"),
    "guitarist": ("Musician", "Music"),
    "rapper": ("Musician", "Music"),
    "conductor": ("Musician", "Music"),

    # Politics, Statesmanship & Governance
    "politician": ("Political Leader", "Politics"),
    "president": ("Political Leader", "Politics"),
    "prime minister": ("Political Leader", "Politics"),
    "head of state": ("Political Leader", "Politics"),
    "monarch": ("Political Leader", "History"),
    "emperor": ("Political Leader", "History"),
    "king": ("Political Leader", "History"),
    "queen": ("Political Leader", "History"),
    "statesman": ("Political Leader", "Politics"),
    "statesperson": ("Political Leader", "Politics"),
    "diplomat": ("Political Leader", "Politics"),
    "chancellor": ("Political Leader", "Politics"),
    "activist": ("Political Leader", "Social Reform"),

    # Literature & Authorship
    "author": ("Author", "Literature"),
    "writer": ("Author", "Literature"),
    "novelist": ("Author", "Literature"),
    "poet": ("Author", "Literature"),
    "playwright": ("Author", "Literature"),
    "journalist": ("Author", "Media"),
    "essayist": ("Author", "Literature"),

    # Visual Arts & Architecture
    "painter": ("Visual Artist", "Fine Arts"),
    "sculptor": ("Visual Artist", "Fine Arts"),
    "architect": ("Visual Artist", "Architecture"),
    "artist": ("Visual Artist", "Fine Arts"),
    "illustrator": ("Visual Artist", "Fine Arts"),
    "photographer": ("Visual Artist", "Fine Arts"),

    # Philosophy & Intellectual Thought
    "philosopher": ("Philosopher", "Philosophy"),
    "theologian": ("Philosopher", "Philosophy"),
    "sociologist": ("Philosopher", "Social Science"),
    "economist": ("Economist", "Economics"),
    "historian": ("Historian", "History"),

    # Innovation, Tech & Business
    "entrepreneur": ("Entrepreneur", "Business"),
    "businessperson": ("Entrepreneur", "Business"),
    "investor": ("Entrepreneur", "Business"),
    "inventor": ("Innovator & Tech", "Technology"),
    "engineer": ("Innovator & Tech", "Engineering"),
    "software engineer": ("Innovator & Tech", "Technology"),
    "tech founder": ("Entrepreneur", "Technology"),

    # Exploration & Space
    "astronaut": ("Astronaut", "Space Exploration"),
    "cosmonaut": ("Astronaut", "Space Exploration"),
    "explorer": ("Explorer", "Exploration"),
    "aviator": ("Aviator", "Aviation"),

    # Military Leadership
    "general": ("Military Leader", "Military History"),
    "military commander": ("Military Leader", "Military History"),
    "admiral": ("Military Leader", "Military History"),

    # Fiction, Pop Culture & Gaming
    "video game character": ("Video Game Character", "Pop Culture"),
    "fictional character": ("Fictional Character", "Pop Culture"),
    "superhero": ("Fictional Character", "Pop Culture"),
    "anime character": ("Fictional Character", "Pop Culture"),
    "hedgehog": ("Hedgehog", "Pop Culture"),
}

MAJOR_ACCOLADES: dict[str, str] = {
    "nobel prize": "Nobel Laureate",
    "nobel laureate": "Nobel Laureate",
    "nobel peace prize": "Nobel Peace Laureate",
    "fifa world cup": "World Cup Champion",
    "world cup": "World Cup Champion",
    "ballon d'or": "Ballon d'Or Winner",
    "olympic medalist": "Olympic Medalist",
    "olympic champion": "Olympic Champion",
    "olympic games": "Olympic Medalist",
    "academy award": "Academy Award Winner",
    "oscar": "Academy Award Winner",
    "grammy award": "Grammy Winner",
    "grammy": "Grammy Winner",
    "super bowl": "Super Bowl Champion",
    "golden globe": "Golden Globe Winner",
    "bafta": "BAFTA Winner",
    "cannes": "Cannes Winner",
    "emmy award": "Emmy Winner",
    "tony award": "Tony Winner",
    "pulitzer": "Pulitzer Winner",
}

LABEL_TO_ICONIC_PERSONAS: dict[str, list[str]] = {
    "film director": [
        "Christopher Nolan", "Quentin Tarantino", "Steven Spielberg", "Martin Scorsese",
        "Stanley Kubrick", "James Cameron", "Alfred Hitchcock", "Hayao Miyazaki",
        "Ridley Scott", "Denis Villeneuve", "David Fincher", "Francis Ford Coppola"
    ],
    "filmmaker": [
        "Christopher Nolan", "Quentin Tarantino", "Steven Spielberg", "Martin Scorsese",
        "Stanley Kubrick", "James Cameron", "Alfred Hitchcock", "Hayao Miyazaki"
    ],
    "cinema & film": [
        "Christopher Nolan", "Christian Bale", "Robert De Niro", "Cillian Murphy",
        "Quentin Tarantino", "Steven Spielberg", "Leonardo DiCaprio", "Marilyn Monroe", "Audrey Hepburn"
    ],
    "philosopher": [
        "Aristotle", "Plato", "Socrates", "Friedrich Nietzsche", "Immanuel Kant",
        "René Descartes", "Confucius", "John Locke", "Voltaire", "Marcus Aurelius"
    ],
    "theoretical physicist": [
        "Albert Einstein", "Stephen Hawking", "Richard Feynman", "J. Robert Oppenheimer",
        "Niels Bohr", "Erwin Schrödinger", "Werner Heisenberg", "Max Planck"
    ],
    "physicist": [
        "Albert Einstein", "Marie Curie", "Isaac Newton", "Nikola Tesla",
        "Stephen Hawking", "Richard Feynman", "J. Robert Oppenheimer"
    ],
    "author": [
        "William Shakespeare", "J. K. Rowling", "J. R. R. Tolkien", "George Orwell",
        "Ernest Hemingway", "Mark Twain", "Stephen King", "Agatha Christie", "Charles Dickens", "Leo Tolstoy"
    ],
    "visual artist": [
        "Leonardo da Vinci", "Vincent van Gogh", "Pablo Picasso", "Michelangelo",
        "Salvador Dalí", "Claude Monet", "Rembrandt", "Frida Kahlo", "Andy Warhol"
    ],
    "entrepreneur": [
        "Steve Jobs", "Elon Musk", "Bill Gates", "Walt Disney",
        "Jeff Bezos", "Mark Zuckerberg", "Henry Ford", "Warren Buffett"
    ],
    "athlete": [
        "Lionel Messi", "Cristiano Ronaldo", "Diego Maradona", "Pele",
        "Michael Jordan", "Muhammad Ali", "Tom Brady", "Usain Bolt", "LeBron James", "Serena Williams"
    ],
    "football player": [
        "Lionel Messi", "Cristiano Ronaldo", "Diego Maradona", "Pele",
        "Zinedine Zidane", "Ronaldinho", "Kylian Mbappé", "Neymar"
    ],
    "scientist": [
        "Albert Einstein", "Marie Curie", "Isaac Newton", "Nikola Tesla",
        "Alan Turing", "Stephen Hawking", "Charles Darwin", "Galileo Galilei"
    ],
    "actor": [
        "Christian Bale", "Cillian Murphy", "Robert De Niro", "Leonardo DiCaprio",
        "Marilyn Monroe", "Audrey Hepburn", "Gal Gadot", "Bruce Lee", "Morgan Freeman"
    ],
    "musician": [
        "Michael Jackson", "Elvis Presley", "Freddie Mercury", "Ludwig van Beethoven",
        "Wolfgang Amadeus Mozart", "The Beatles", "Bob Dylan", "Taylor Swift"
    ],
    "political leader": [
        "Abraham Lincoln", "Winston Churchill", "Mahatma Gandhi", "Nelson Mandela",
        "Julius Caesar", "Alexander the Great", "Cleopatra", "Napoleon"
    ],
    "video game character": [
        "Sonic the Hedgehog", "Mario", "Luigi", "Pac-Man", "Link", "Crash Bandicoot", "Master Chief"
    ],
    "nobel laureate": [
        "Albert Einstein", "Marie Curie", "Richard Feynman", "Winston Churchill", "Nelson Mandela", "Ernest Hemingway"
    ],
    "world cup champion": [
        "Lionel Messi", "Diego Maradona", "Pele", "Zinedine Zidane", "Kylian Mbappé"
    ],
    "academy award winner": [
        "Christopher Nolan", "Christian Bale", "Cillian Murphy", "Robert De Niro",
        "Quentin Tarantino", "Steven Spielberg", "Leonardo DiCaprio", "Audrey Hepburn"
    ],
    "japan": [
        "Hayao Miyazaki", "Akira Kurosawa", "Hideo Kojima", "Haruki Murakami", "Shigeru Miyamoto"
    ],
    "france": [
        "Napoleon", "Marie Curie", "Claude Monet", "Victor Hugo", "René Descartes", "Zinedine Zidane"
    ],
    "brazil": [
        "Pele", "Ayrton Senna", "Ronaldinho", "Neymar"
    ],
    "argentina": [
        "Lionel Messi", "Diego Maradona", "Che Guevara", "Jorge Luis Borges"
    ],
    "united kingdom": [
        "Christopher Nolan", "Winston Churchill", "William Shakespeare", "Isaac Newton",
        "Stephen Hawking", "Alan Turing", "Christian Bale", "Audrey Hepburn"
    ],
    "united states": [
        "Abraham Lincoln", "Steve Jobs", "Muhammad Ali", "Michael Jordan",
        "Michael Jackson", "Elvis Presley", "Walt Disney", "Nikola Tesla"
    ],
    "technology": [
        "Steve Jobs", "Elon Musk", "Bill Gates", "Alan Turing", "Nikola Tesla"
    ],
    "sports": [
        "Lionel Messi", "Cristiano Ronaldo", "Diego Maradona", "Pele", "Michael Jordan", "Muhammad Ali", "Tom Brady"
    ],
    "physics": [
        "Albert Einstein", "Stephen Hawking", "Marie Curie", "Isaac Newton", "Richard Feynman"
    ],
}

def clean_wikidata_attribute_name(raw: str) -> str:
    clean = raw.strip()
    lower = clean.lower()

    # Block chivalric orders, decorations, titles, honours, minor medals, and noisy attributes
    BLOCKED_SUBSTRINGS = [
        "order of the british empire", "order of the", "order of ", "commander of",
        "officer of the", "member of the", "knight bachelor", "knight commander",
        "dame commander", "chevalier", "legion of honour", "cbe", "obe", "mbe", "kbe",
        "star of", "cross of", "fellow of", "honorary", "doctorate", "degree",
        "disambiguation", "wikimedia", "living person", "broadcasting", "alumnus",
        "alumni", "fellowship", "human", "male", "female", "person", "notable figure",
        "icon", "cultural legend", "republic", "territory", "district", "borough",
    ]
    if any(b in lower for b in BLOCKED_SUBSTRINGS):
        return ""

    if len(clean) > 30 or clean.count(" ") >= 4:
        return ""

    if lower == "association football player": return "Football Player"
    if lower == "association football club": return "Football Club"
    if lower == "association football": return "Football"
    if lower == "anthropomorphic hedgehog": return "Hedgehog"
    if lower == "video game character": return "Video Game Character"
    if lower == "united states of america": return "United States"
    if lower == "argentine republic": return "Argentina"
    if "nobel prize" in lower or "nobel laureate" in lower: return "Nobel Laureate"
    if "academy award" in lower or "oscar" in lower: return "Academy Award Winner"
    if "golden globe" in lower: return "Golden Globe Winner"
    if "bafta" in lower: return "BAFTA Winner"
    if "grammy" in lower: return "Grammy Winner"
    if "world cup" in lower: return "World Cup Champion"
    if "ballon d'or" in lower: return "Ballon d'Or Winner"

    # If it ends with award/awards/prize/medal but didn't match a major accolade above, drop it
    if any(lower.endswith(w) or lower == w for w in ["awards", "award", "prize", "medal", "medals", "cup", "trophy"]):
        return ""

    clean = re.sub(r"\s*\([^)]*\)", "", clean).strip()
    return clean.title() if clean.islower() else clean

async def resolve_wikidata_qids(client: httpx.AsyncClient, qids: List[str]) -> dict[str, str]:
    needed = [q for q in qids if q and q.startswith("Q") and q not in WIKIDATA_QID_LABELS]
    if needed:
        try:
            params = {
                "action": "wbgetentities",
                "ids": "|".join(needed[:40]),
                "props": "labels",
                "languages": "en",
                "format": "json"
            }
            res = await client.get("https://www.wikidata.org/w/api.php", params=params, headers=HEADERS, timeout=5.0)
            if res.status_code == 200:
                ent_data = res.json().get("entities", {})
                for q, d in ent_data.items():
                    val = d.get("labels", {}).get("en", {}).get("value")
                    if val:
                        cleaned = clean_wikidata_attribute_name(val)
                        if cleaned:
                            WIKIDATA_QID_LABELS[q] = cleaned
        except Exception:
            pass
    return {q: WIKIDATA_QID_LABELS[q] for q in qids if q in WIKIDATA_QID_LABELS}

async def extract_persona_labels_from_wikidata(
    client: httpx.AsyncClient, 
    claims: dict, 
    desc: str = "", 
    title: str = ""
) -> List[str]:
    target_qids = []
    # Separate core properties from awards (P166) so awards NEVER leak into general other_attrs
    for prop in ["P106", "P27", "P495", "P101", "P136", "P39", "P31"]:
        stmts = claims.get(prop, [])
        for stmt in stmts[:3]:
            val = stmt.get("mainsnak", {}).get("datavalue", {}).get("value")
            if isinstance(val, dict) and "id" in val:
                qid = val["id"]
                if qid not in target_qids:
                    target_qids.append(qid)
            if len(target_qids) >= 12:
                break
        if len(target_qids) >= 12:
            break

    # P166 awards specifically for detecting major prestigious accolades only
    award_qids = []
    for stmt in claims.get("P166", [])[:6]:
        val = stmt.get("mainsnak", {}).get("datavalue", {}).get("value")
        if isinstance(val, dict) and "id" in val:
            qid = val["id"]
            if qid not in award_qids:
                award_qids.append(qid)

    all_qids = list(set(target_qids + award_qids))
    resolved_items: List[str] = []
    award_items: List[str] = []
    if all_qids:
        resolved = await resolve_wikidata_qids(client, all_qids)
        for q in target_qids:
            if q in resolved:
                lbl = resolved[q]
                if lbl and lbl not in resolved_items:
                    resolved_items.append(lbl)
        for q in award_qids:
            if q in resolved:
                lbl = resolved[q]
                if lbl and lbl not in award_items:
                    award_items.append(lbl)

    super_category = None
    domain = None
    primary_roles: List[str] = []
    countries: List[str] = []
    accolades: List[str] = []
    other_attrs: List[str] = []

    combined_text = f"{title} {desc} " + " ".join(resolved_items) + " " + " ".join(award_items)
    combined_lower = combined_text.lower()

    # Process awards solely against MAJOR_ACCOLADES
    for a_item in award_items:
        lower_a = a_item.lower()
        for ack_key, ack_val in MAJOR_ACCOLADES.items():
            if ack_key in lower_a and ack_val not in accolades:
                accolades.append(ack_val)
                break

    for item in resolved_items:
        lower_item = item.lower()
        # Accolade check
        for ack_key, ack_val in MAJOR_ACCOLADES.items():
            if ack_key in lower_item and ack_val not in accolades:
                accolades.append(ack_val)
                break
        
        # Super-category & domain check
        if lower_item in COMPREHENSIVE_SUPER_CATEGORIES:
            cat, dom = COMPREHENSIVE_SUPER_CATEGORIES[lower_item]
            if not super_category:
                super_category = cat
            if not domain:
                domain = dom
            if item not in primary_roles:
                primary_roles.append(item)
        elif any(c_kw in lower_item for c_kw in [
            "argentina", "france", "united states", "united kingdom", "germany",
            "italy", "spain", "brazil", "poland", "egypt", "japan", "china",
            "india", "mexico", "portugal", "ireland", "scotland", "canada",
            "australia", "south africa", "netherlands", "sweden", "israel", "greece"
        ]):
            if item not in countries:
                countries.append(item)
        else:
            # Only add to other_attrs if not an award and is clean/short
            is_award_like = any(w in lower_item for w in ["award", "prize", "winner", "order", "honour", "medal", "cup", "trophy"])
            if not is_award_like and len(item) <= 24 and item not in other_attrs and item not in accolades:
                other_attrs.append(item)

    # Fallback deduction if super-category or domain not resolved
    if not super_category or not domain:
        for key, (cat, dom) in COMPREHENSIVE_SUPER_CATEGORIES.items():
            if key in combined_lower:
                if not super_category:
                    super_category = cat
                if not domain:
                    domain = dom
                break

    for ack_key, ack_val in MAJOR_ACCOLADES.items():
        if ack_key in combined_lower and ack_val not in accolades:
            accolades.append(ack_val)

    if not countries:
        nationalities_map = {
            "argentina": "Argentina", "argentine": "Argentina", "brazil": "Brazil", "brazilian": "Brazil",
            "france": "France", "french": "France", "portugal": "Portugal", "portuguese": "Portugal",
            "spain": "Spain", "spanish": "Spain", "italy": "Italy", "italian": "Italy",
            "germany": "Germany", "german": "Germany", "england": "England", "english": "England",
            "british": "United Kingdom", "united states": "United States", "american": "United States",
            "poland": "Poland", "polish": "Poland", "egypt": "Egypt", "egyptian": "Egypt",
            "japan": "Japan", "japanese": "Japan", "china": "China", "chinese": "China",
            "india": "India", "mexico": "Mexico", "ireland": "Ireland",
            "netherlands": "Netherlands", "dutch": "Netherlands", "sweden": "Sweden", "swedish": "Sweden"
        }
        for k, v in nationalities_map.items():
            if k in combined_lower:
                countries.append(v)
                break

    # Assemble comprehensive, non-specific labels in prioritized order:
    final_labels: List[str] = []
    if super_category:
        final_labels.append(super_category)
    for r in primary_roles:
        if r not in final_labels:
            final_labels.append(r)
            if len(final_labels) >= 2:
                break
    for c in countries:
        if c not in final_labels:
            final_labels.append(c)
            break
    for a in accolades:
        if a not in final_labels:
            final_labels.append(a)
            if len(final_labels) >= 4:
                break
    if domain and domain not in final_labels and domain != super_category:
        final_labels.append(domain)
    for o in other_attrs:
        if o not in final_labels:
            final_labels.append(o)
        if len(final_labels) >= 6:
            break

    if final_labels:
        return final_labels[:6]

    return extract_attributes_from_description(desc, title)

def extract_attributes_from_description(desc: str, title: str) -> List[str]:
    if not desc and not title:
        return []
    clean_desc = re.sub(r"\s*\([^)]*\)", "", desc or "").strip()
    text = f"{title} {clean_desc}".lower()
    
    super_category = None
    domain = None
    primary_roles: List[str] = []
    countries: List[str] = []
    accolades: List[str] = []

    for key, (cat, dom) in COMPREHENSIVE_SUPER_CATEGORIES.items():
        if key in text:
            if not super_category:
                super_category = cat
            if not domain:
                domain = dom
            title_case_key = key.title()
            if title_case_key not in primary_roles and title_case_key != cat:
                primary_roles.append(title_case_key)
            if len(primary_roles) >= 2:
                break

    for ack_key, ack_val in MAJOR_ACCOLADES.items():
        if ack_key in text and ack_val not in accolades:
            accolades.append(ack_val)

    nationalities = {
        "argentina": "Argentina", "argentine": "Argentina", "brazil": "Brazil", "brazilian": "Brazil",
        "france": "France", "french": "France", "portugal": "Portugal", "portuguese": "Portugal",
        "spain": "Spain", "spanish": "Spain", "italy": "Italy", "italian": "Italian",
        "germany": "Germany", "german": "Germany", "england": "England", "english": "England",
        "british": "United Kingdom", "united states": "United States", "american": "United States",
        "poland": "Poland", "polish": "Poland", "egypt": "Egypt", "egyptian": "Egypt",
        "japan": "Japan", "japanese": "Japan", "china": "China", "chinese": "China",
        "india": "India", "mexico": "Mexico", "ireland": "Ireland"
    }
    for k, v in nationalities.items():
        if k in text:
            countries.append(v)
            break

    final_labels: List[str] = []
    if super_category:
        final_labels.append(super_category)
    for r in primary_roles:
        if r not in final_labels:
            final_labels.append(r)
    for c in countries:
        if c not in final_labels:
            final_labels.append(c)
    for a in accolades:
        if a not in final_labels:
            final_labels.append(a)
    if domain and domain not in final_labels and domain != super_category:
        final_labels.append(domain)

    return final_labels[:6]

async def get_persona_labels_async(client: httpx.AsyncClient, title: str, claims: dict = None, desc: str = "") -> List[str]:
    if claims and isinstance(claims, dict) and claims:
        return await extract_persona_labels_from_wikidata(client, claims, desc=desc, title=title)
    
    try:
        params = {
            "action": "wbgetentities",
            "sites": "enwiki",
            "titles": title,
            "props": "claims|descriptions",
            "languages": "en",
            "format": "json"
        }
        res = await client.get("https://www.wikidata.org/w/api.php", params=params, headers=HEADERS, timeout=5.0)
        if res.status_code == 200:
            entities = res.json().get("entities", {})
            for qid, ent in entities.items():
                if qid != "-1":
                    c = ent.get("claims", {})
                    d = ent.get("descriptions", {}).get("en", {}).get("value", desc)
                    return await extract_persona_labels_from_wikidata(client, c, desc=d, title=title)
    except Exception:
        pass
    
    return extract_attributes_from_description(desc, title)

def generate_persona_labels(title: str, description: str = "") -> List[str]:
    return extract_attributes_from_description(description, title)


class RecommendRequest(BaseModel):
    liked_personas: List[str] = Field(default_factory=list, example=["Christian Bale", "Robert De Niro"])
    viewed_personas: Optional[List[str]] = Field(default_factory=list, example=["Leonardo DiCaprio"])
    searched_queries: Optional[List[str]] = Field(default_factory=list, example=["space exploration"])
    limit: int = Field(6, ge=1, le=20)


# -------------------------------------------------------------------
# Helper Utilities
# -------------------------------------------------------------------
def sanitize_collection_name(name: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9_]", "_", name.lower())
    return f"entity_{cleaned}"[:63]


def chunk_text(text: str, chunk_size: int = 300, overlap: int = 50) -> List[str]:
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
    clean_title = title.replace(" ", "_").strip()
    
    async with httpx.AsyncClient(follow_redirects=True, timeout=10.0) as client:
        # 1. First check summary
        rest_url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{urllib.parse.quote(clean_title)}"
        try:
            res = await client.get(rest_url, headers=HEADERS)
            if res.status_code == 200:
                data = res.json()
                page_type = data.get("type", "")
                extract = data.get("extract", "")
                
                # Check for disambiguation
                if page_type == "disambiguation" or "may refer to:" in extract.lower() or "refer to:" in extract.lower():
                    # Resolve to character article
                    search_res = await client.get(
                        f"https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch={urllib.parse.quote(title)}+character&utf8=1&format=json&srlimit=5",
                        headers=HEADERS
                    )
                    search_titles = [x["title"] for x in search_res.json().get("query", {}).get("search", [])]
                    for cand in search_titles:
                        if "list of" in cand.lower():
                            continue
                        c_res = await client.get(f"https://en.wikipedia.org/api/rest_v1/page/summary/{urllib.parse.quote(cand.replace(' ', '_'))}", headers=HEADERS)
                        if c_res.status_code == 200 and c_res.json().get("type") != "disambiguation":
                            c_extract = c_res.json().get("extract", "")
                            if len(c_extract) > 100:
                                return c_extract
                elif len(extract) > 100:
                    return extract
        except Exception:
            pass

        # 2. Try character article directly if title doesn't already specify it
        if not clean_title.lower().endswith("_(character)"):
            try:
                char_url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{urllib.parse.quote(clean_title)}_(character)"
                c_res = await client.get(char_url, headers=HEADERS)
                if c_res.status_code == 200:
                    c_data = c_res.json()
                    if c_data.get("type") != "disambiguation" and len(c_data.get("extract", "")) > 100:
                        return c_data["extract"]
            except Exception:
                pass

        # 3. Action API fallback
        action_url = "https://en.wikipedia.org/w/api.php"
        params = {
            "action": "query", 
            "prop": "extracts", 
            "exintro": True, 
            "explaintext": True, 
            "titles": clean_title, 
            "format": "json", 
            "redirects": 1
        }
        res_action = await client.get(action_url, params=params, headers=HEADERS)
        if res_action.status_code == 200:
            pages = res_action.json().get("query", {}).get("pages", {})
            for page_id, page_data in pages.items():
                if page_id != "-1" and "extract" in page_data:
                    ext = page_data["extract"].strip()
                    if "may refer to:" not in ext.lower() and len(ext) > 100:
                        return ext

    raise HTTPException(status_code=404, detail=f"Could not retrieve Wikipedia text for '{title}'.")


DDGS_IMAGE_CACHE: dict[str, List[str]] = {}

BLOCKED_P31_IDS = {
    # Video games, franchises, media
    "Q7889",      # video game
    "Q7058673",   # video game series
    "Q1068270",   # game series
    "Q141546978", # video game franchise
    "Q1966271",   # media franchise
    "Q33837",     # franchise
    "Q112144412", # arcade video game
    "Q11424",     # film
    "Q24856",     # film series
    "Q202866",    # animated film
    "Q5398426",   # television series
    "Q169930",    # television program
    "Q7397",      # software
    "Q11266",     # board game
    "Q4830453",   # business enterprise / company
    "Q43229",     # organization
    "Q4167410",   # Wikimedia disambiguation page
    "Q13406463",  # Wikimedia list article
    "Q63032896",  # Wikimedia list article
    "Q482994",    # album
    "Q7366",      # song
    "Q134556",    # single
    "Q53147",     # video game console
    "Q8274",      # manga series
    "Q1107",      # anime
    "Q860861",    # toy
    "Q515",       # city
    "Q6256",      # country
    # Concepts, professions, occupations, movements, ideologies, phenomena
    "Q12737077",  # occupation / social role (e.g. athlete, artist, singer, actor)
    "Q28640",     # profession
    "Q151885",    # concept
    "Q88789639",  # human activity
    "Q1323572",   # social movement (e.g. feminism, activism)
    "Q203764",    # activism
    "Q1188843",   # cultural phenomenon / pop icon
    "Q11862829",  # academic discipline
    "Q21198",     # field of study / academic discipline
    "Q4671286",   # branch of philosophy
    "Q107434",    # social movement
    "Q179805",    # political ideology
    "Q7144970",   # political movement
    "Q188451",    # social movement
    "Q16334295",  # group of humans
    "Q125191",    # movement
    "Q28855038",  # subculture
    "Q46884",     # genre
    "Q135106813", # profession
    "Q66715801",  # occupation
    "Q108300140", # occupation
    "Q103810966", # occupation
    "Q4164871",   # profession
    "Q273057",    # abstract object
    "Q1656682",   # event
    "Q1190554",   # occurrence
    "Q15284",     # municipality
    "Q486972",    # human settlement
    "Q35127",     # website / web portal
    "Q7278",      # political party
    "Q327333",    # government agency
    "Q3918",      # university
    "Q2385804",   # educational institution
}

VALID_PERSONA_P31_IDS = {
    "Q5",          # human
    "Q95074",      # fictional character
    "Q15632617",   # fictional human
    "Q21070568",   # fictional anthropomorphic animal
    "Q22695507",   # video game character
    "Q15773347",   # video game protagonist
    "Q15773317",   # video game antagonist
    "Q15711870",   # video game character
    "Q88594381",   # video game character
    "Q138750110",  # fictional anthropomorphic hedgehog
    "Q215627",     # fictional person
    "Q1114461",    # comic book character
    "Q3658341",    # literary character
    "Q11062925",   # anime character
    "Q12308941",   # mythical character
    "Q245068",     # comic strip character
    "Q4271324",    # mythological character
    "Q1486857",    # animated character
    "Q2807869",    # video game boss
    "Q130003",     # deity
    "Q22971",      # legendary figure
    "Q1569167",    # fictional entity
    "Q386208"      # fictional creature
}

BLOCKED_CONCEPT_KEYWORDS = [
    "occupation", "profession", "social movement", "political movement", "ideology",
    "academic discipline", "branch of", "field of study", "human activity",
    "efforts to make change", "celebrity, character or object regarded", "movement that",
    "group of movements", "study of questions", "practice of", "form of",
    "video game", "arcade game", "racing game", "platform game", "media franchise",
    "video game series", "game series", "television series", "film directed",
    "disambiguation page", "list of", "album by", "song by", "cultural phenomenon",
    "musical group", "band formed", "rock band", "pop group", "genre of", "type of"
]

CHARACTER_KEYWORDS = [
    "fictional character", "video game character", "comic book character",
    "literary character", "anime character", "protagonist", "antagonist",
    "mascot", "player character", "title character", "mythological character",
    "deity", "mythical character", "legendary figure"
]


def is_valid_persona(p31_ids: list, claims: dict = None, desc: str = "", title: str = "") -> bool:
    """Strictly validates that an entity represents an individual person (human) or fictional character."""
    claims = claims or {}
    desc_lower = (desc or "").lower()
    title_lower = (title or "").lower()

    # 1. Explicit blocked suffixes in title (MUST be first to block things like 'Control (video game)')
    if any(title_lower.endswith(suffix) for suffix in [
        "(video game)", "(game)", "(franchise)", "(series)", "(film)", "(movie)",
        "(album)", "(song)", "(single)", "(soundtrack)", "(concept)", "(profession)",
        "(occupation)", "(movement)", "(genre)", "(tv series)", "(television series)",
        "(band)", "(musical group)", "(software)", "(novel)", "(book)", "(company)",
        "(brand)", "(organization)", "(organisation)", "(city)", "(country)", "(state)"
    ]):
        return False

    # 2. Blocked P31 check
    if any(pid in BLOCKED_P31_IDS for pid in p31_ids):
        has_human_or_char = ("Q5" in p31_ids) or any(pid in VALID_PERSONA_P31_IDS for pid in p31_ids)
        if not has_human_or_char:
            return False

    # 3. Block concept keywords in description unless it is explicitly an iconic character
    if any(kw in desc_lower for kw in BLOCKED_CONCEPT_KEYWORDS):
        if not any(ckw in desc_lower for ckw in CHARACTER_KEYWORDS):
            return False

    # 4. Check for Real Human:
    # In Wikidata, Q5 is human. Humans also have P569 (birth date), P21 (gender), P106 (occupation)
    if "Q5" in p31_ids:
        return True
    if "P569" in claims and ("P21" in claims or "P106" in claims):
        return True

    # 5. Check for Fictional Character:
    if any(pid in VALID_PERSONA_P31_IDS for pid in p31_ids):
        if not any(kw in desc_lower for kw in BLOCKED_CONCEPT_KEYWORDS) or any(ckw in desc_lower for ckw in CHARACTER_KEYWORDS):
            return True

    if any(ckw in desc_lower for ckw in CHARACTER_KEYWORDS):
        return True

    # Disallow all concepts, movements, professions, and non-humans
    return False


def get_wikimedia_direct_url(filename: str) -> str:
    cleaned = filename.replace(' ', '_').strip()
    md5 = hashlib.md5(cleaned.encode('utf-8')).hexdigest()
    return f"https://upload.wikimedia.org/wikipedia/commons/{md5[0]}/{md5[0:2]}/{cleaned}"


def fetch_free_images_sync(query: str, num_images: int = 6) -> List[str]:
    clean_query = re.sub(r"\(.*?\)", "", query).strip()
    cache_key = f"{clean_query.lower()}_{num_images}"
    if cache_key in DDGS_IMAGE_CACHE:
        return DDGS_IMAGE_CACHE[cache_key]

    search_query = f"{clean_query} character render art" if any(w in query.lower() for w in ["character", "sonic", "mario", "pac-man", "crash", "donkey kong", "link"]) else f"{clean_query} portrait"
    try:
        try:
            results = DDGS().images(query=search_query, max_results=num_images)
        except TypeError:
            results = DDGS().images(keywords=search_query, max_results=num_images)

        urls = []
        for item in results:
            img = item.get("image")
            if img and img.startswith("http") and not img.lower().endswith((".svg", ".tif", ".tiff")):
                urls.append(img)

        if urls:
            DDGS_IMAGE_CACHE[cache_key] = urls
        return urls
    except Exception as e:
        print(f"DuckDuckGo image search error for '{query}': {e}")
        return []


async def fetch_web_images(query: str, num_images: int = 6) -> List[str]:
    return await asyncio.to_thread(fetch_free_images_sync, query, num_images)


async def search_wikipedia_fuzzy(client: httpx.AsyncClient, query: str, limit: int = 5) -> List[str]:
    params = {
        "action": "query",
        "list": "search",
        "srsearch": query,  
        "utf8": 1,
        "format": "json",
        "srlimit": limit
    }
    try:
        res = await client.get("https://en.wikipedia.org/w/api.php", params=params, headers=HEADERS)
        search_results = res.json().get("query", {}).get("search", [])
        if not search_results:
            params["srsearch"] = f"{query}~"
            res_fuzzy = await client.get("https://en.wikipedia.org/w/api.php", params=params, headers=HEADERS)
            search_results = res_fuzzy.json().get("query", {}).get("search", [])
        return [item["title"] for item in search_results]
    except Exception:
        return []


PERSONA_CARD_CACHE: dict[str, PersonaSearchResult] = {}


async def build_single_persona_card(client: httpx.AsyncClient, name: str) -> Optional[PersonaSearchResult]:
    clean_name = name.strip()
    if clean_name.lower() in PERSONA_CARD_CACHE:
        return PERSONA_CARD_CACHE[clean_name.lower()]

    try:
        # Build candidate titles: exact name, character suffix, and character search
        candidates = [clean_name]
        if not clean_name.lower().endswith("(character)"):
            candidates.append(f"{clean_name} (character)")
        if "sonic" in clean_name.lower() and not clean_name.lower().startswith("sonic the hedgehog"):
            candidates.append("Sonic the Hedgehog (character)")

        # Wikipedia search for candidates and character variants
        wiki_titles = await search_wikipedia_fuzzy(client, clean_name, limit=3)
        char_wiki_titles = await search_wikipedia_fuzzy(client, f"{clean_name} character", limit=3)

        all_titles = []
        for t in candidates + char_wiki_titles + wiki_titles:
            if t and t not in all_titles and "list of" not in t.lower():
                all_titles.append(t)

        wd_params = {
            "action": "wbgetentities", 
            "sites": "enwiki", 
            "titles": "|".join(all_titles[:8]), 
            "props": "claims|labels|descriptions|sitelinks", 
            "languages": "en", 
            "format": "json"
        }
        ent_res = await client.get("https://www.wikidata.org/w/api.php", params=wd_params, headers=HEADERS)
        entities = ent_res.json().get("entities", {})

        title_to_entity = {}
        for qid, ent in entities.items():
            if qid == "-1": continue
            en_title = ent.get("sitelinks", {}).get("enwiki", {}).get("title")
            if en_title:
                title_to_entity[en_title] = (qid, ent)

        for title in all_titles:
            if title in title_to_entity:
                qid, entity = title_to_entity[title]
                claims = entity.get("claims", {})
                p31_ids = [stmt.get("mainsnak", {}).get("datavalue", {}).get("value", {}).get("id") for stmt in claims.get("P31", [])]
                desc = entity.get("descriptions", {}).get("en", {}).get("value", "")

                if is_valid_persona(p31_ids, claims=claims, desc=desc, title=title):
                    image_url = None
                    if "P18" in claims:
                        try:
                            filename = claims["P18"][0]["mainsnak"]["datavalue"]["value"]
                            if not filename.lower().endswith(('.svg', '.tif', '.tiff')):
                                image_url = get_wikimedia_direct_url(filename)
                        except Exception: 
                            pass
                    
                    if not image_url:
                        # Try Wikipedia summary thumbnail
                        try:
                            sum_res = await client.get(f"https://en.wikipedia.org/api/rest_v1/page/summary/{urllib.parse.quote(title)}", headers=HEADERS)
                            if sum_res.status_code == 200:
                                image_url = sum_res.json().get("thumbnail", {}).get("source")
                        except Exception:
                            pass

                    if not image_url:
                        fallback = await fetch_web_images(clean_name, num_images=1)
                        if fallback: 
                            image_url = fallback[0]
                    
                    label = entity.get("labels", {}).get("en", {}).get("value", clean_name)
                    # Clean title display if it has (character) suffix
                    clean_display_title = re.sub(r"\s*\(character\)$", "", label, flags=re.IGNORECASE)
                    
                    card = PersonaSearchResult(
                        title=clean_display_title,
                        description=desc or "Known persona",
                        wikidata_id=qid,
                        image_url=image_url,
                        labels=await extract_persona_labels_from_wikidata(client, claims, desc=desc, title=clean_display_title)
                    )
                    PERSONA_CARD_CACHE[clean_name.lower()] = card
                    PERSONA_CARD_CACHE[title.lower()] = card
                    PERSONA_CARD_CACHE[card.title.lower()] = card
                    return card
    except Exception: 
        pass

    # Fallback to Wikipedia summary ONLY if it's a valid persona and not a video game / disambiguation / concept
    try:
        rest_url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{urllib.parse.quote(clean_name)}"
        res = await client.get(rest_url, headers=HEADERS)
        if res.status_code == 200:
            data = res.json()
            page_type = data.get("type", "")
            desc = data.get("description", "")
            if page_type != "disambiguation" and is_valid_persona([], claims={}, desc=desc, title=clean_name):
                title = data.get("title", clean_name)
                img = data.get("thumbnail", {}).get("source")
                if not img:
                    ddg_imgs = await fetch_web_images(clean_name, num_images=1)
                    img = ddg_imgs[0] if ddg_imgs else None
                card = PersonaSearchResult(
                    title=title, 
                    description=desc or "Known persona", 
                    wikidata_id="", 
                    image_url=img,
                    labels=await get_persona_labels_async(client, title, desc=desc)
                )
                PERSONA_CARD_CACHE[clean_name.lower()] = card
                return card
    except Exception:
        pass
    
    return None


async def verify_human_and_fetch_images(entity_name: str, limit: int = 6) -> tuple[str, List[str]]:
    image_urls: List[str] = []
    official_wikipedia_title = entity_name
    selected_claims = None
    human_found = False

    async with httpx.AsyncClient(follow_redirects=True, timeout=10.0) as client:
        # Build candidate titles including character variants
        candidates = [entity_name]
        if not entity_name.lower().endswith("(character)"):
            candidates.append(f"{entity_name} (character)")
        if "sonic" in entity_name.lower() and not entity_name.lower().startswith("sonic the hedgehog"):
            candidates.append("Sonic the Hedgehog (character)")

        fuzzy_titles = await search_wikipedia_fuzzy(client, entity_name, limit=5)
        char_fuzzy_titles = await search_wikipedia_fuzzy(client, f"{entity_name} character", limit=5)

        titles = []
        for t in candidates + char_fuzzy_titles + fuzzy_titles:
            if t and t not in titles and "list of" not in t.lower():
                titles.append(t)

        if titles:
            wd_params = {
                "action": "wbgetentities", 
                "sites": "enwiki", 
                "titles": "|".join(titles[:8]), 
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
                if title in title_to_entity:
                    qid, entity = title_to_entity[title]
                    claims = entity.get("claims", {})
                    p31_ids = [stmt.get("mainsnak", {}).get("datavalue", {}).get("value", {}).get("id") for stmt in claims.get("P31", [])]
                    desc = entity.get("descriptions", {}).get("en", {}).get("value", "")

                    if is_valid_persona(p31_ids, claims=claims, desc=desc, title=title):
                        human_found = True
                        selected_claims = claims
                        official_wikipedia_title = title
                        break

        if not human_found:
            search_params = {
                "action": "wbsearchentities", 
                "search": entity_name, 
                "language": "en", 
                "format": "json", 
                "limit": 5
            }
            res = await client.get("https://www.wikidata.org/w/api.php", params=search_params, headers=HEADERS)
            
            for item in res.json().get("search", []):
                candidate_qid = item.get("id")
                if not candidate_qid: continue
                
                entity_res = await client.get(f"https://www.wikidata.org/wiki/Special:EntityData/{candidate_qid}.json", headers=HEADERS)
                if entity_res.status_code != 200: continue
                
                entity_data = entity_res.json()
                claims = entity_data.get("entities", {}).get(candidate_qid, {}).get("claims", {})
                p31_ids = [stmt.get("mainsnak", {}).get("datavalue", {}).get("value", {}).get("id") for stmt in claims.get("P31", [])]
                desc = item.get("description", "")
                
                if is_valid_persona(p31_ids, claims=claims, desc=desc, title=item.get("label", "")):
                    human_found = True
                    selected_claims = claims
                    sitelinks = entity_data.get("entities", {}).get(candidate_qid, {}).get("sitelinks", {})
                    if "enwiki" in sitelinks: 
                        official_wikipedia_title = sitelinks["enwiki"].get("title", entity_name)
                    break

        if selected_claims:
            try:
                p18 = selected_claims.get("P18", [{}])[0].get("mainsnak", {}).get("datavalue", {}).get("value")
                if p18 and not p18.lower().endswith(('.svg', '.tif', '.tiff')):
                    image_urls.append(get_wikimedia_direct_url(p18))

                commons_category = selected_claims.get("P373", [{}])[0].get("mainsnak", {}).get("datavalue", {}).get("value")
                if commons_category:
                    comm_params = {
                        "action": "query", 
                        "generator": "categorymembers", 
                        "gcmtitle": f"Category:{commons_category}", 
                        "gcmtype": "file", 
                        "gcmlimit": limit * 2, 
                        "prop": "imageinfo", 
                        "iiprop": "url", 
                        "format": "json"
                    }
                    comm_res = await client.get("https://commons.wikimedia.org/w/api.php", params=comm_params, headers=HEADERS)
                    if comm_res.status_code == 200:
                        for page_info in comm_res.json().get("query", {}).get("pages", {}).values():
                            img_url = page_info.get("imageinfo", [{}])[0].get("url")
                            if img_url and img_url.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
                                if img_url not in image_urls:
                                    image_urls.append(img_url)
            except Exception: 
                pass

        # Try Wikipedia REST thumbnail if no images found yet
        if not image_urls:
            try:
                sum_res = await client.get(f"https://en.wikipedia.org/api/rest_v1/page/summary/{urllib.parse.quote(official_wikipedia_title)}", headers=HEADERS)
                if sum_res.status_code == 200:
                    thumb = sum_res.json().get("thumbnail", {}).get("source")
                    if thumb:
                        image_urls.append(thumb)
            except Exception:
                pass

    # Ensure we have up to limit images using DuckDuckGo
    if len(image_urls) < limit:
        needed = limit - len(image_urls)
        try:
            fallback_images = await fetch_web_images(official_wikipedia_title, num_images=needed)
            for url in fallback_images:
                if url not in image_urls: 
                    image_urls.append(url)
        except Exception: 
            pass

    if len(image_urls) < limit:
        needed = limit - len(image_urls)
        try:
            extra_images = await fetch_web_images(entity_name, num_images=needed)
            for url in extra_images:
                if url not in image_urls:
                    image_urls.append(url)
        except Exception:
            pass

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
async def discover_personas(limit: int = 6, page: int = 1, ts: Optional[float] = None):
    """
    Returns a paginated, randomized assortment of personas for infinite scroll.
    Uses an isolated RNG seeded by `ts` (session timestamp) so the same session
    produces a consistent, non-overlapping pagination sequence.
    """
    if ts is not None:
        try:
            seed = int(float(ts))
        except (ValueError, TypeError):
            seed = hash(str(ts))
        rng = random.Random(seed)
    else:
        rng = random.Random()

    pool_len = len(DISCOVER_POOL)
    if pool_len == 0:
        return []

    shuffled_pool = DISCOVER_POOL.copy()
    rng.shuffle(shuffled_pool)

    page_num = max(1, page)
    requested_limit = max(1, min(limit, 30))
    start_idx = (page_num - 1) * requested_limit

    candidate_names: List[str] = []
    for i in range(start_idx, start_idx + requested_limit + 10):
        candidate = shuffled_pool[i % pool_len]
        if candidate not in candidate_names:
            candidate_names.append(candidate)
        if len(candidate_names) >= requested_limit + 6:
            break

    async with httpx.AsyncClient(timeout=10.0) as client:
        uncached = [name for name in candidate_names if name.lower() not in PERSONA_CARD_CACHE]
        if uncached:
            try:
                batch_res = await client.get(
                    "https://en.wikipedia.org/w/api.php",
                    params={
                        "action": "query",
                        "titles": "|".join(uncached[:25]),
                        "prop": "pageimages|description",
                        "piprop": "thumbnail",
                        "pithumbsize": 600,
                        "format": "json"
                    },
                    headers=HEADERS
                )
                if batch_res.status_code == 200:
                    pages = batch_res.json().get("query", {}).get("pages", {})
                    for p in pages.values():
                        title = p.get("title", "")
                        desc = p.get("description", "Notable persona")
                        thumb = p.get("thumbnail", {}).get("source")
                        if title and thumb:
                            card = PersonaSearchResult(
                                title=title,
                                description=desc or "Notable persona",
                                wikidata_id="",
                                image_url=thumb,
                                labels=generate_persona_labels(title, desc)
                            )
                            PERSONA_CARD_CACHE[title.lower()] = card
            except Exception:
                pass

        tasks = []
        for name in candidate_names:
            if name.lower() in PERSONA_CARD_CACHE:
                tasks.append(asyncio.sleep(0, result=PERSONA_CARD_CACHE[name.lower()]))
            else:
                tasks.append(build_single_persona_card(client, name))
        results = await asyncio.gather(*tasks, return_exceptions=True)

    valid_results = [res for res in results if isinstance(res, PersonaSearchResult)]
    return valid_results[:requested_limit]

@app.post("/api/v1/personas/recommend", response_model=List[PersonaSearchResult])
async def recommend_personas(payload: RecommendRequest):
    liked = [p.strip() for p in (payload.liked_personas or []) if p and p.strip()]
    viewed = [p.strip() for p in (payload.viewed_personas or []) if p and p.strip()]
    searched = [p.strip() for p in (payload.searched_queries or []) if p and p.strip()]

    # If user has no interaction signals yet, fall back to discover
    if not liked and not viewed and not searched:
        return await discover_personas(payload.limit, page=1)

    profile_lines = []
    if liked:
        profile_lines.append(f"- FAVORITED / LOVED PERSONAS (highest priority): {', '.join(liked)}")
    if viewed:
        profile_lines.append(f"- RECENTLY VIEWED & EXPLORED: {', '.join(viewed)}")
    if searched:
        profile_lines.append(f"- RECENT SEARCH QUERIES / TOPICS: {', '.join(searched)}")

    profile_summary = "\n".join(profile_lines)

    prompt = (
        f"You are the StarTrack intelligent persona recommendation engine.\n"
        f"The user has demonstrated interest through the following interactions:\n"
        f"{profile_summary}\n\n"
        f"Recommend {payload.limit} famous individual persons or iconic characters that this user would love to discover next based on their taste, domain, era, and style.\n"
        f"STRICT RULES:\n"
        f"1. ONLY recommend individual people or iconic characters (e.g. Leonardo da Vinci, Marie Curie, Lionel Messi, Luigi, Sonic the Hedgehog, Nelson Mandela).\n"
        f"2. DO NOT recommend anyone already listed in their favorited or viewed lists.\n"
        f"3. NEVER recommend concepts, roles, professions, or movements (e.g. DO NOT say 'Pop Icon', 'Athlete', 'Activism', 'Artist', 'Philosophy').\n"
        f"4. NEVER recommend video game titles, franchises, film names, or companies (e.g. DO NOT say 'Super Mario Bros', 'Marvel', 'Nintendo').\n"
        f"5. Return ONLY a comma-separated list of their specific person or character names. Do not include any other text."
    )
    
    try:
        completion = groq_client.chat.completions.create(
            model="openai/gpt-oss-120b", 
            messages=[{"role": "user", "content": prompt}],
            temperature=0.7, 
            max_tokens=600
        )
        llm_response = completion.choices[0].message.content or ""
        if not llm_response.strip():
            llm_response = getattr(completion.choices[0].message, "reasoning", "") or ""
        suggested_names = []
        for name in llm_response.split(","):
            cleaned_n = re.sub(r"^(etc\.\s*(could be:?)?|e\.g\.?:?|such as:?|\d+\.|\-|\*)\s*", "", name.strip(), flags=re.IGNORECASE).strip()
            if cleaned_n:
                suggested_names.append(cleaned_n)
    except Exception as e:
        print(f"Groq recommendation failed: {e}")
        return await discover_personas(payload.limit, page=1)

    async with httpx.AsyncClient(timeout=15.0) as client:
        tasks = [build_single_persona_card(client, name) for name in suggested_names[:payload.limit * 2]]
        results = await asyncio.gather(*tasks)
    
    seen_titles = {p.lower().strip() for p in (liked + viewed)}
    unique_results = []
    for card in results:
        if card is not None and card.title.lower().strip() not in seen_titles:
            seen_titles.add(card.title.lower().strip())
            unique_results.append(card)

    if len(unique_results) < payload.limit:
        fallback_results = await discover_personas(payload.limit * 2, page=1)
        for card in fallback_results:
            if card.title.lower().strip() not in seen_titles:
                seen_titles.add(card.title.lower().strip())
                unique_results.append(card)
            if len(unique_results) >= payload.limit:
                break

    return unique_results[:payload.limit]

@app.get("/api/v1/personas/image")
async def get_persona_main_image(q: str):
    """Fetch a high-res portrait image for a persona via DuckDuckGo."""
    imgs = await fetch_web_images(q, num_images=1)
    return {"image_url": imgs[0] if imgs else None}


@app.get("/api/v1/personas/images")
async def get_persona_gallery_images(q: str, limit: int = 6):
    """Fetch gallery images for a persona via DuckDuckGo."""
    imgs = await fetch_web_images(q, num_images=limit)
    return {"image_urls": imgs}


SEARCH_CACHE: dict[str, List[PersonaSearchResult]] = {}


@app.get("/api/v1/search/personas", response_model=List[PersonaSearchResult])
async def search_human_personas(q: str):
    """Fast, Typo-Tolerant, relevance-ranked search returning ONLY characters and people, filtering out video games."""
    clean_q = q.strip().lower()
    if not clean_q:
        return []
    if clean_q in SEARCH_CACHE:
        return SEARCH_CACHE[clean_q]

    human_results = []
    
    async with httpx.AsyncClient(timeout=10.0) as client:
        titles = await search_wikipedia_fuzzy(client, q, limit=12)

        # Match label queries to iconic personas for instant rich results
        for l_key, l_personas in LABEL_TO_ICONIC_PERSONAS.items():
            if clean_q == l_key or clean_q in l_key or l_key in clean_q:
                for lp in reversed(l_personas):
                    if lp not in titles:
                        titles.insert(0, lp)

        # Search by label: find personas associated with this label/profession/attribute
        label_queries = [f"famous {clean_q}"]
        if clean_q in ["athlete", "scientist", "actor", "musician", "political leader", "author", "visual artist", "entrepreneur", "philosopher", "nobel laureate", "world cup champion", "video game character", "football player", "physicist", "film director", "filmmaker", "director"]:
            label_queries.append(f"list of {clean_q}s")
        for lq in label_queries:
            extra_titles = await search_wikipedia_fuzzy(client, lq, limit=6)
            for lt in extra_titles:
                if lt not in titles and not lt.lower().startswith("list of"):
                    titles.append(lt)

        cache_matched = [
            card.title for card in PERSONA_CARD_CACHE.values()
            if any(clean_q.lower() == l.lower() or clean_q.lower() in l.lower() for l in card.labels)
        ]
        for cm in cache_matched:
            if cm not in titles:
                titles.insert(0, cm)

        if titles:
            wd_params = {
                "action": "wbgetentities", 
                "sites": "enwiki", 
                "titles": "|".join(titles), 
                "props": "claims|labels|descriptions|sitelinks", 
                "languages": "en", 
                "format": "json"
            }
            # Concurrently fetch Wikidata entities and Wikipedia pageimages
            ent_task = client.get("https://www.wikidata.org/w/api.php", params=wd_params, headers=HEADERS)
            pi_params = {
                "action": "query",
                "prop": "pageimages",
                "piprop": "thumbnail",
                "pithumbsize": 500,
                "titles": "|".join(titles),
                "format": "json"
            }
            pi_task = client.get("https://en.wikipedia.org/w/api.php", params=pi_params, headers=HEADERS)

            ent_res, pi_res = await asyncio.gather(ent_task, pi_task, return_exceptions=True)

            entities_data = {}
            if isinstance(ent_res, httpx.Response) and ent_res.status_code == 200:
                entities_data = ent_res.json().get("entities", {})

            title_to_thumb = {}
            if isinstance(pi_res, httpx.Response) and pi_res.status_code == 200:
                pages = pi_res.json().get("query", {}).get("pages", {})
                title_to_thumb = {p.get("title"): p.get("thumbnail", {}).get("source") for p in pages.values() if "thumbnail" in p}
            
            title_to_entity = {ent.get("sitelinks", {}).get("enwiki", {}).get("title"): (qid, ent) for qid, ent in entities_data.items() if qid != "-1"}

            for title in titles:
                if title not in title_to_entity: 
                    continue
                    
                qid, entity = title_to_entity[title]
                claims = entity.get("claims", {})
                p31_ids = [stmt.get("mainsnak", {}).get("datavalue", {}).get("value", {}).get("id") for stmt in claims.get("P31", [])]
                desc = entity.get("descriptions", {}).get("en", {}).get("value", "")

                # Strictly check if persona/character (blocks video games, films, series, concepts, professions)
                if is_valid_persona(p31_ids, claims=claims, desc=desc, title=title):
                    image_url = None
                    if "P18" in claims:
                        try:
                            filename = claims["P18"][0]["mainsnak"]["datavalue"]["value"]
                            if not filename.lower().endswith(('.svg', '.tif', '.tiff')):
                                image_url = get_wikimedia_direct_url(filename)
                        except Exception: 
                            pass
                    
                    if not image_url and title in title_to_thumb:
                        image_url = title_to_thumb[title]

                    label = entity.get("labels", {}).get("en", {}).get("value", title)
                    clean_display_title = re.sub(r"\s*\(character\)$", "", label, flags=re.IGNORECASE)
                    
                    human_results.append(PersonaSearchResult(
                        title=clean_display_title, 
                        description=desc or "Known persona", 
                        wikidata_id=qid, 
                        image_url=image_url,
                        labels=await extract_persona_labels_from_wikidata(client, claims, desc=desc, title=clean_display_title)
                    ))
                    
                    if len(human_results) >= 20: 
                        break

        if not human_results:
            search_params = {
                "action": "wbsearchentities", 
                "search": q, 
                "language": "en", 
                "format": "json", 
                "limit": 12
            }
            res = await client.get("https://www.wikidata.org/w/api.php", params=search_params, headers=HEADERS)
            qids = [item["id"] for item in res.json().get("search", []) if "id" in item]
            
            if qids:
                ent_params = {
                    "action": "wbgetentities", 
                    "ids": "|".join(qids), 
                    "props": "claims", 
                    "format": "json"
                }
                ent_res = await client.get("https://www.wikidata.org/w/api.php", params=ent_params, headers=HEADERS)
                entities_data = ent_res.json().get("entities", {})
                
                for item in res.json().get("search", []):
                    qid = item["id"]
                    claims = entities_data.get(qid, {}).get("claims", {})
                    p31_ids = [stmt.get("mainsnak", {}).get("datavalue", {}).get("value", {}).get("id") for stmt in claims.get("P31", [])]
                    desc = item.get("description", "")
                    
                    if is_valid_persona(p31_ids, claims=claims, desc=desc, title=item.get("label", "")):
                        image_url = None
                        if "P18" in claims:
                            try:
                                filename = claims["P18"][0]["mainsnak"]["datavalue"]["value"]
                                if not filename.lower().endswith(('.svg', '.tif', '.tiff')):
                                    image_url = get_wikimedia_direct_url(filename)
                            except Exception: 
                                pass
                        
                        clean_display_title = re.sub(r"\s*\(character\)$", "", item.get("label", ""), flags=re.IGNORECASE)
                        human_results.append(PersonaSearchResult(
                            title=clean_display_title, 
                            description=desc or "Known persona", 
                            wikidata_id=qid, 
                            image_url=image_url,
                            labels=await extract_persona_labels_from_wikidata(client, claims, desc=desc, title=clean_display_title)
                        ))
                        
                        if len(human_results) >= 20: 
                            break

    if human_results:
        SEARCH_CACHE[clean_q] = human_results
    return human_results


RAG_CACHE: dict[str, RAGQueryResponse] = {}


@app.post("/api/v1/rag/query", response_model=RAGQueryResponse)
async def perform_rag_query(payload: RAGQueryRequest):
    format_mode = getattr(payload, "format_type", "standard") or "standard"
    is_cards_mode = (format_mode == "cards") or ("cards" in payload.user_query.lower()) or ("swipeable" in payload.user_query.lower())

    cache_key = f"{payload.entity_name.lower().strip()}_{format_mode}_{payload.user_query.lower().strip()}"
    if cache_key in RAG_CACHE:
        cached_ans = RAG_CACHE[cache_key].answer.lower()
        # Invalidate cache if it contains disambiguation disclaimers or apologies
        if "refer to:" not in cached_ans and "doesn't contain enough" not in cached_ans and "could you share" not in cached_ans and "clarification" not in cached_ans:
            return RAG_CACHE[cache_key]
        else:
            del RAG_CACHE[cache_key]

    total_start = time.time()
    
    t0 = time.time()
    try:
        verified_title, entity_images = await verify_human_and_fetch_images(payload.entity_name, limit=6)
    except Exception:
        verified_title = payload.wikipedia_title or payload.entity_name
        entity_images = await fetch_web_images(payload.entity_name, num_images=6)

    if not entity_images:
        entity_images = await fetch_web_images(payload.entity_name, num_images=6)

    try:
        raw_text = await fetch_wikipedia_text(verified_title)
    except Exception:
        try:
            raw_text = await fetch_wikipedia_text(payload.entity_name)
        except Exception:
            raw_text = f"{payload.entity_name} is a renowned figure and iconic persona."

    hydration_ms = (time.time() - t0) * 1000

    t1 = time.time()
    chunks = chunk_text(raw_text, chunk_size=300, overlap=50)
    if not chunks: 
        chunks = [f"{payload.entity_name} overview information."]

    embeddings = embedding_model.encode(chunks, convert_to_numpy=True)
    collection_name = sanitize_collection_name(verified_title)
    
    qdrant_client.recreate_collection(
        collection_name=collection_name, 
        vectors_config=VectorParams(size=embeddings.shape[1], distance=Distance.COSINE)
    )

    points = [PointStruct(id=idx, vector=vector.tolist(), payload={"text": chunk}) for idx, (chunk, vector) in enumerate(zip(chunks, embeddings))]
    qdrant_client.upsert(collection_name=collection_name, points=points)
    indexing_ms = (time.time() - t1) * 1000

    t2 = time.time()
    query_vector = embedding_model.encode(payload.user_query).tolist()
    search_results = qdrant_client.query_points(
        collection_name=collection_name, 
        query=query_vector, 
        limit=payload.top_k
    ).points
    
    filtered_chunks = [res for res in search_results if res.score >= payload.similarity_threshold]
    final_results = filtered_chunks if filtered_chunks else search_results

    retrieved_chunks = [ChunkMetadata(chunk_id=res.id, text=res.payload["text"], similarity_score=round(res.score, 4)) for res in final_results]
    search_ms = (time.time() - t2) * 1000

    t3 = time.time()
    context_blocks = "\n\n".join([f"[Source Chunk {c.chunk_id}]: {c.text}" for c in retrieved_chunks])
    
    if is_cards_mode:
        system_prompt = (
            f"You are the StarTrack AI Entity Assistant.\n"
            f"Create a JSON object containing exactly 7 concise, captivating overview cards for '{payload.entity_name}'.\n"
            f"CRITICAL RULES:\n"
            f"- Return ONLY a JSON object with a single 'cards' key: {{\"cards\": [ ... ]}}.\n"
            f"- Each card must have ONLY two fields:\n"
            f"  \"title\": A clean, descriptive section header (e.g. \"Who is {payload.entity_name}?\", \"Origins & Early Life\", \"Career Breakthroughs\", \"Signature Style & Craft\", \"Major Honors & Records\", \"Cultural Impact & Legacy\", \"Fascinating Trivia & Curiosities\").\n"
            f"  \"content\": 2 to 3 engaging, polished narrative sentences about that aspect.\n"
            f"- NEVER output raw JSON inside 'content'.\n"
            f"- NEVER include disambiguation apologies or mentions of other people.\n"
            f"- Do NOT include badges, tags, or extra fields."
        )
        user_prompt = f"Context:\n{context_blocks}\n\nCreate the 7 overview cards for '{payload.entity_name}'."
        max_tokens_val = 1400
    else:
        # Full comprehensive, big overview for AI chat and inquiries
        system_prompt = (
            f"You are the StarTrack AI Entity Assistant — a master biographical intelligence.\n"
            f"You generate engaging, comprehensive, and authoritative biographical overviews about notable figures, celebrities, iconic athletes, and iconic characters.\n"
            f"CRITICAL DIRECTIVES:\n"
            f"- The subject of this inquiry is '{payload.entity_name}'. If '{payload.entity_name}' represents an iconic fictional or video game character (such as Sonic the Hedgehog, Mario, Pac-Man, Link, Crash Bandicoot, etc.), you must recognize and discuss them definitively as that iconic protagonist and character.\n"
            f"- NEVER output disambiguation apologies, phrases like 'may refer to', or requests for user clarification.\n"
            f"- Structure your response with a captivating, comprehensive synthesis covering their creation/origins, distinctive characteristics/powers, key story roles/adventures, awards/achievements, and lasting cultural legacy.\n"
            f"- Synthesize the provided context with your deep knowledge to deliver a rich, polished answer.\n"
            f"- PROACTIVE FOLLOW-UP: Conclude by asking the user if they want more information, deep dives into their career triumphs, awards, or fascinating trivia about {payload.entity_name}."
        )
        user_prompt = f"Context:\n{context_blocks}\n\nQuestion: {payload.user_query}"
        max_tokens_val = 1200

    overview_cards: Optional[List[OverviewCard]] = None

    try:
        completion_params = {
            "model": "openai/gpt-oss-120b",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            "temperature": 0.2,
            "max_tokens": max_tokens_val
        }
        if is_cards_mode:
            completion_params["response_format"] = {"type": "json_object"}

        completion = groq_client.chat.completions.create(**completion_params)
        ai_answer = completion.choices[0].message.content or ""
        if not ai_answer.strip():
            reasoning = getattr(completion.choices[0].message, "reasoning", "") or ""
            if len(reasoning.strip()) > 50:
                ai_answer = reasoning.strip()
            else:
                ai_answer = raw_text[:600] + ("..." if len(raw_text) > 600 else "")
    except Exception as e:
        print(f"Groq API Inference issue: {e}")
        ai_answer = raw_text[:600] + ("..." if len(raw_text) > 600 else "")

    if is_cards_mode:
        # Attempt to parse overview_cards from JSON output
        parsed_cards: List[OverviewCard] = []
        try:
            clean_ai = ai_answer.strip()
            if clean_ai.startswith("```"):
                clean_ai = re.sub(r"^```(?:json)?\s*", "", clean_ai)
                clean_ai = re.sub(r"\s*```$", "", clean_ai)

            data = json.loads(clean_ai)
            raw_items = []
            if isinstance(data, dict):
                raw_items = data.get("cards") or data.get("overview_cards") or []
            elif isinstance(data, list):
                raw_items = data

            for item in raw_items:
                if isinstance(item, dict) and "title" in item and "content" in item:
                    t = str(item.get("title", "")).strip()
                    c = str(item.get("content", "")).strip()
                    # Sanitize: ensure content is not raw JSON string
                    if c and not c.startswith("{") and not c.startswith("[") and not c.startswith("```") and "category" not in c[:30]:
                        parsed_cards.append(OverviewCard(
                            title=t,
                            content=c
                        ))
        except Exception as err:
            print(f"Cards JSON parsing note: {err}")

        # Fallback card generation: USE CLEAN WIKIPEDIA TEXT, NEVER USE FAILED AI_ANSWER WITH JSON!
        if len(parsed_cards) < 6:
            clean_wiki = re.sub(r'#+\s*', '', raw_text).strip()
            wiki_paras = [p.strip() for p in clean_wiki.split("\n\n") if len(p.strip()) > 30 and not p.strip().startswith("{") and not p.strip().startswith("[") and "category" not in p[:30]]

            fallback_titles = [
                f"Who is {payload.entity_name}?",
                "Origins & Early Life",
                "Career Breakthroughs",
                "Signature Style & Craft",
                "Major Honors & Accolades",
                "Cultural Impact & Legacy",
                "Fascinating Trivia & Curiosities",
            ]
            fallback_cards: List[OverviewCard] = []
            for idx, title in enumerate(fallback_titles):
                snippet = wiki_paras[idx] if idx < len(wiki_paras) else (wiki_paras[0] if wiki_paras else f"{payload.entity_name} is an internationally recognized figure celebrated for outstanding achievements.")
                if len(snippet) > 280:
                    snippet = snippet[:277] + "..."
                fallback_cards.append(OverviewCard(
                    title=title,
                    content=snippet
                ))
            parsed_cards = fallback_cards

        overview_cards = parsed_cards
        ai_answer = "\n\n".join([f"**{c.title}**\n{c.content}" for c in overview_cards])
    
    llm_ms = (time.time() - t3) * 1000
    total_ms = (time.time() - total_start) * 1000
    
    if retrieved_chunks:
        avg_score = round(sum(c.similarity_score for c in retrieved_chunks) / len(retrieved_chunks), 4)
    else:
        avg_score = 0.0

    telemetry = PerformanceTelemetry(
        hydration_latency_ms=round(hydration_ms, 2), 
        vector_indexing_latency_ms=round(indexing_ms, 2), 
        vector_search_latency_ms=round(search_ms, 2), 
        llm_inference_latency_ms=round(llm_ms, 2), 
        total_execution_ms=round(total_ms, 2), 
        avg_similarity_score=avg_score
    )

    rag_labels: List[str] = []
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            rag_labels = await get_persona_labels_async(client, payload.entity_name)
    except Exception:
        rag_labels = generate_persona_labels(payload.entity_name)

    result = RAGQueryResponse(
        entity=payload.entity_name, 
        answer=ai_answer, 
        image_urls=entity_images, 
        retrieved_chunks=retrieved_chunks, 
        telemetry=telemetry,
        overview_cards=overview_cards,
        labels=rag_labels
    )
    RAG_CACHE[cache_key] = result
    return result


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
