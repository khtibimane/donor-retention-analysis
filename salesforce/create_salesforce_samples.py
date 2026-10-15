"""
Create Salesforce import files from the simulated donor data.

Samples 500 donors (random_state=42) and all of their gifts, then writes
accounts and opportunities CSVs with Salesforce column names.
"""
import os

import pandas as pd

DATA_DIR = "data"
OUT_DIR = "salesforce"
SAMPLE_SIZE = 500
SEED = 42

donors = pd.read_csv(f"{DATA_DIR}/donors.csv")
gifts = pd.read_csv(f"{DATA_DIR}/gifts.csv")

# Sample donors, keep all of their gifts
sample_donors = donors.sample(n=SAMPLE_SIZE, random_state=SEED)
sample_gifts = gifts[gifts["donor_id"].isin(sample_donors["donor_id"])]

# Donor -> Salesforce Account
accounts = pd.DataFrame({
    "Account Name": "Donor " + sample_donors["donor_id"],
    "Donor ID": sample_donors["donor_id"],
    "Donor Type": sample_donors["donor_type"],
    "Donor State": sample_donors["state"],
})

# Gift -> Salesforce Opportunity
opps = pd.DataFrame({
    "Opportunity Name": "Gift " + sample_gifts["gift_id"],
    "Donor ID": sample_gifts["donor_id"],
    "Gift ID": sample_gifts["gift_id"],
    "Amount": sample_gifts["amount"],
    "Close Date": sample_gifts["gift_date"],
    "Stage": "Closed Won",
    "Gift Campaign": sample_gifts["campaign"],
    "Channel": sample_gifts["channel"],
})

os.makedirs(OUT_DIR, exist_ok=True)
accounts.to_csv(f"{OUT_DIR}/accounts_sample.csv", index=False)
opps.to_csv(f"{OUT_DIR}/opportunities_sample.csv", index=False)

# Validation
print("Donors:", len(accounts))
print("Gifts:", len(opps))
print("Gifts without a matching donor:",
      (~opps["Donor ID"].isin(accounts["Donor ID"])).sum())