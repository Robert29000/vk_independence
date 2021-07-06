import os
from brownie import Independence, accounts

def main():
    account = accounts.add(os.getenv("PRIVATE_KEY"))
    independence = Independence.deploy("8dd3ae0f8dd3ae0f8dd3ae0f548dabd7c788dd38dd3ae0fed31e2a5b3e013231d5c30db", 
                                {'from': account})