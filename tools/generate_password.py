import argparse

import bcrypt


parser = argparse.ArgumentParser(
    description="Genera un hash bcrypt para guardar en la tabla login."
)
parser.add_argument("password", help="Contraseña que se desea convertir en hash")
args = parser.parse_args()

password_hash = bcrypt.hashpw(
    args.password.encode("utf-8"), bcrypt.gensalt()
).decode("utf-8")

print(password_hash)
