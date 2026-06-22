import os
import jwt
from flask import request, g
from flask_login import login_user
from flask_appbuilder.security.manager import AUTH_DB
from superset import db
from superset.security import SupersetSecurityManager
from celery.schedules import crontab

POSTGRES_USER = os.environ.get("POSTGRES_USER")
POSTGRES_PASSWORD = os.environ.get("POSTGRES_PASSWORD")
POSTGRES_HOST = os.environ.get("POSTGRES_HOST", "postgres")
POSTGRES_PORT = os.environ.get("POSTGRES_PORT", "5432")
POSTGRES_DB = os.environ.get("POSTGRES_DB")
RECAPTCHA_PUBLIC_KEY = os.environ.get("RECAPTCHA_PUBLIC_KEY")
RECAPTCHA_PRIVATE_KEY = os.environ.get("RECAPTCHA_PRIVATE_KEY")
SQLALCHEMY_DATABASE_URI = (
    f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@"
    f"{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}"
)
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY")
REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = os.environ.get("REDIS_PORT", "6379")
REDIS_PASSWORD = os.environ.get("REDIS_PASSWORD", "")
REDIS_URL = f"redis://:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}"
FAB_API_ALLOWED_FIELD_FILTERS = ["id", "name", "username", "first_name", "last_name"]
FAB_API_ALLOWED_REL_FIELDS = {"permission": ["id", "name"], "view_menu": ["id", "name"]}
FAB_ADD_SECURITY_PERMISSION_VIEWS = True

JWT_ALGORITHM = "RS256"
pub_key_path = os.environ.get("PATH_PUBLICKEY")

try:
    with open(pub_key_path, "r") as f:
        JWT_PUBLIC_KEY = f.read()
except Exception:
    JWT_PUBLIC_KEY = ""

class MySecurityManager(SupersetSecurityManager):
    def init(self, appbuilder):
        super(MySecurityManager, self).init(appbuilder)

        @self.jwt_manager.user_lookup_loader
        def user_lookup_callback(_jwt_header, jwt_data):
            return self._get_or_create_jwt_user(jwt_data)

    def has_access(self, permission_name, view_name):
        import jwt
        from flask import request, g
        from flask_login import current_user, login_user
        if current_user.is_anonymous and request.method != "OPTIONS":
            auth_header = request.headers.get("Authorization")
            if auth_header and auth_header.startswith("Bearer "):
                token = auth_header.split(" ")[1]
                try:
                    payload = jwt.decode(
                        token,
                        JWT_PUBLIC_KEY,
                        algorithms=["RS256"],
                        options={"verify_aud": False}
                    )
                    user = self._get_or_create_jwt_user(payload)
                    if user:
                        login_user(user, remember=False)
                        g.user = user
                except Exception:
                    pass
        return super().has_access(permission_name, view_name)

    def load_user(self, pk):
        try:
            return self.get_user_by_id(int(pk))
        except (ValueError, TypeError):
            return self.find_user(username=str(pk)) or self.find_user(email=str(pk))

    def load_user_jwt(self, _jwt_header, jwt_data):
        return self._get_or_create_jwt_user(jwt_data)

    def _get_or_create_jwt_user(self, payload):
        email = payload.get("email")
        if not email:
            return None
        roles_to_assign = []
        company_data = payload.get("company_id")
        empresas = company_data if company_data is not None else []
        if not isinstance(empresas, list):
            empresas = [empresas]
        for cid in empresas:
            company_role = self.find_role(str(cid))
            if company_role:
                roles_to_assign.append(company_role)
        if not roles_to_assign:
            public_role = self.find_role("Public")
            if not public_role:
                public_role = self.add_role("Public")
                try:
                    db.session.commit()
                except Exception:
                    db.session.rollback()
            if public_role:
                roles_to_assign.append(public_role)
        if not roles_to_assign:
            return None
        user = self.find_user(email=email)
        if not user:
            try:
                fname = payload.get("first_name") or payload.get("username") or "JWT"
                lname = payload.get("last_name") or "User"
                user = self.add_user(
                    username=email,
                    first_name=payload.get("first_name", fname),
                    last_name=payload.get("last_name", lname),
                    email=email,
                    role=roles_to_assign
                )
                db.session.commit()
            except Exception:
                db.session.rollback()
                return None
        else:
            try:
                user.roles = roles_to_assign
                db.session.commit()
            except Exception:
                db.session.rollback()
        g.user = user
        return user

AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Public"
CUSTOM_SECURITY_MANAGER = MySecurityManager
AUTH_TYPE = AUTH_DB

CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_cache_",
    "CACHE_REDIS_URL": f"{REDIS_URL}/0",
}

class CeleryConfig:
    broker_url = f"{REDIS_URL}/1"
    imports = ("superset.sql_lab",)
    result_backend = f"{REDIS_URL}/2"
    worker_prefetch_multiplier = 10
    task_track_started = True
    task_acks_late = True
    beat_schedule = {
        "reports.scheduler": {
            "task": "reports.scheduler",
            "schedule": crontab(minute="*", hour="*"),
        },
        "reports.prune_log": {
            "task": "reports.prune_log",
            "schedule": crontab(minute=0, hour=2),
        },
    }
CELERY_CONFIG = CeleryConfig
FEATURE_FLAGS = {
    "ENABLE_TEMPLATE_PROCESSING": True,
    "ALLOW_FILE_UPLOAD": True,
    "DASHBOARD_RBAC": True,
}
RATELIMIT_STORAGE_URI = f"{REDIS_URL}/3"
