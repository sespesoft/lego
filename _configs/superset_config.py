import os
import jwt
from flask import request, g
from flask_login import login_user
from flask_appbuilder.security.manager import AUTH_DB
from superset.security import SupersetSecurityManager
from celery.schedules import crontab

POSTGRES_USER = os.environ.get("POSTGRES_USER")
POSTGRES_PASSWORD = os.environ.get("POSTGRES_PASSWORD")
POSTGRES_HOST = os.environ.get("POSTGRES_HOST", "postgres")
POSTGRES_PORT = os.environ.get("POSTGRES_PORT", "5432")
POSTGRES_DB = os.environ.get("POSTGRES_DB")
SQLALCHEMY_DATABASE_URI = (
    f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@"
    f"{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}"
)
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY")
REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = os.environ.get("REDIS_PORT", "6379")
REDIS_PASSWORD = os.environ.get("REDIS_PASSWORD", "")
REDIS_URL = f"redis://:{REDIS_PASSWORD}@{REDIS_HOST}:{REDIS_PORT}"

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

        @appbuilder.app.before_request
        def before_request_auth():
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
                except Exception:
                    pass

    def ensure_reader_role_exists(self):
        role_name = "reader"
        role = self.find_role(role_name)
        if not role:
            role = self.add_role(role_name)
        perms = [
            ("can_read", "Dashboard"),
            ("can_read", "Chart"),
            ("can_read", "Dataset"),
            ("menu_access", "Dashboards"),
        ]
        role_changed = False
        for perm_name, view_name in perms:
            pv = self.find_permission_view_menu(perm_name, view_name)
            if pv and pv not in role.permissions:
                role.permissions.append(pv)
                role_changed = True
        if role_changed:
            self.get_session.commit()
        return role

    def _get_or_create_jwt_user(self, payload):
        email = payload.get("email")
        username = payload.get("username")
        user = self.find_user(email=email)
        if not user:
            role = self.ensure_reader_role_exists()
            user = self.add_user(
                username=email,
                first_name=payload.get("first_name", username),
                last_name=payload.get("last_name", "wuser"),
                email=email,
                role=[role]
            )
            self.get_session.commit()
        if user:
            g.user = user
        return user

AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "reader"
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
    "EMBEDDED_SUPERSET": True,
    "TAGGING_SYSTEM": True,
}
RATELIMIT_STORAGE_URI = f"{REDIS_URL}/3"
