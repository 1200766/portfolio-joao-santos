from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from core.database import supabase, db_clinical

bearer_scheme = HTTPBearer()


async def verify_token(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> dict:
    """
    Verifica o JWT emitido pelo Supabase Auth.
    Injeta os dados do utilizador autenticado em cada endpoint protegido.
    Uso: def my_endpoint(user=Depends(verify_token))
    """
    token = credentials.credentials

    try:
        # O Supabase valida o token e devolve os dados da sessão
        response = supabase.auth.get_user(token)
        user = response.user

        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token inválido ou expirado.",
            )

        # Busca dados do perfil (role, name) na tabela public.users
        profile = db_clinical().table("users") \
            .select("id, name, role, active") \
            .eq("id", user.id) \
            .single() \
            .execute()

        if not profile.data:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Utilizador sem perfil registado.",
            )

        if profile.data.get("active") is False:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Conta desactivada. Contacte o administrador.",
            )

        return {
            "id":    profile.data["id"],
            "name":  profile.data["name"],
            "role":  profile.data["role"],
            "email": user.email,
        }

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
            detail="Não autorizado.",
        )


def require_role(*roles: str):
    """
    Dependência de autorização por role.
    Uso: def my_endpoint(user=Depends(require_role("doctor", "admin")))
    """
    async def _check(user: dict = Depends(verify_token)):
        if user["role"] not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Acesso restrito a: {', '.join(roles)}.",
            )
        return user
    return _check
