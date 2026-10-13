import os
import sys
from getpass import getpass

from pycognito import Cognito
from pycognito.exceptions import SoftwareTokenMFAChallengeException

# Logs in with SRP (the app client allows nothing else) and prints the ID token.
# Prompts go to the terminal, not stdout, so TOKEN=$(...) captures only the token.

if len(sys.argv) != 2:
    sys.exit("usage: python tests/get_token.py <email>")

user = Cognito(
    os.environ["USER_POOL_ID"],
    os.environ["USER_POOL_CLIENT_ID"],
    username=sys.argv[1],
)

try:
    user.authenticate(password=getpass("Password: "))
except SoftwareTokenMFAChallengeException:
    user.respond_to_software_token_mfa_challenge(getpass("MFA code: "))

print(user.id_token)
