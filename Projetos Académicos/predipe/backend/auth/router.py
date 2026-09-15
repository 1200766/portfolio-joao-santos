from fastapi import APIRouter, HTTPException, status
from models.schemas import LoginInput, TokenResponse
from core.database import db_clinical, new_anon_client

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
def login(data: LoginInput):

    try:
        auth_client = new_anon_client()
        response = auth_client.auth.sign_in_with_password({
            "email":    data.email,
            "password": data.password,
        })
        user    = response.user
        session = response.session

        if not user or not session:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Email ou palavra-passe incorretos.",
            )

        # Busca perfil na tabela public.users
        profile = db_clinical().table("users") \
            .select("id, name, role, active") \
            .eq("id", user.id) \
            .single() \
            .execute()

        if not profile.data:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Utilizador sem perfil registado. Contacte o administrador.",
            )

        if profile.data.get("active") is False:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Conta desactivada. Contacte o administrador.",
            )

        # Verifica se o role corresponde ao que o frontend enviou
        if profile.data["role"] != data.role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Esta conta não tem perfil de '{data.role}'.",
            )

        return TokenResponse(
            access_token=session.access_token,
            role=profile.data["role"],
            name=profile.data["name"],
            id=profile.data["id"],
        )

    except HTTPException:
        raise
    except RuntimeError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Backend clínico não configurado.",
        ) from error
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou palavra-passe incorretos.",
        )


"""
@router.post("/login")
def login(data: LoginInput):
    print("1 - A tentar login com:", data.email)

    response = supabase.auth.sign_in_with_password({
        "email":    data.email,
        "password": data.password,
    })
    print("2 - Auth OK, user id:", response.user.id)

    profile = supabase.table("users") \
        .select("id, name, role") \
        .eq("id", response.user.id) \
        .execute()
    print("3 - Profile:", profile.data)

    return {"ok": True, "profile": profile.data}
"""


@router.post("/logout")
def logout():
    """
    A API não mantém uma sessão de aplicação no servidor. O cliente tem de
    eliminar o token local; a revogação central exige um fluxo Supabase próprio.
    """
    return {"message": "Elimine o token no cliente para terminar a sessão local."}
