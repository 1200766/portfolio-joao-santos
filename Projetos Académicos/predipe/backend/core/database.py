import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

url: str = os.getenv("SUPABASE_URL")
publishable_key: str = os.getenv("SUPABASE_PUBLISHABLE_KEY")

if not url or not publishable_key:
    raise RuntimeError(
        "SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY têm de estar definidos no ficheiro .env"
    )

supabase: Client = create_client(url, publishable_key)

_secret_key = os.getenv("SUPABASE_SECRET_KEY")
supabase_admin: Client | None = (
    create_client(url, _secret_key) if _secret_key else None
)


def new_anon_client() -> Client:
    """Cliente isolado para fluxos de autenticação que alteram a sessão local."""
    return create_client(url, publishable_key)


def db_clinical() -> Client:
    """
    Cliente exclusivamente server-side para tabelas clínicas.

    A secret key autentica como ``service_role`` e ignora RLS. As rotas que a
    utilizam têm, por isso, de validar primeiro a pertença no backend.
    """
    if supabase_admin is None:
        raise RuntimeError(
            "SUPABASE_SECRET_KEY é necessária para as operações clínicas."
        )
    return supabase_admin
