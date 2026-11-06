from flask import Flask

from .config import Config


def create_app(test_config=None):
    """Crea y configura la aplicación Flask."""
    app = Flask(__name__)
    app.config.from_object(Config)

    if test_config:
        app.config.update(test_config)

    from .auth import auth_bp
    from .main import main_bp
    from .players import players_bp
    from .teams import teams_bp
    from .venues import venues_bp
    from .matches import matches_bp
    from .sheets import sheets_bp
    from .sanctions import sanctions_bp
    from .reports import reports_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(main_bp)
    app.register_blueprint(players_bp)
    app.register_blueprint(teams_bp)
    app.register_blueprint(venues_bp)
    app.register_blueprint(matches_bp)
    app.register_blueprint(sheets_bp)
    app.register_blueprint(sanctions_bp)
    app.register_blueprint(reports_bp)

    return app

