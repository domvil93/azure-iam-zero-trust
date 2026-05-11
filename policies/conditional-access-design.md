# Conditional Access Policy Design — Contoso Zero Trust

## Overview

Conditional Access is the enforcement layer of Contoso's Zero Trust architecture.
Where security groups and RBAC define WHAT each team can access, Conditional 
Access defines WHEN and HOW that access is permitted.

Zero Trust principle: never trust, always verify. Every access request is 
evaluated against conditions — location, device state, sign-in risk, user role — 
regardless of whether the request originates inside or outside the network.

> **Implementation note:** These policies require Entra ID P1 licence. 
> This document represents the design and architectural decisions. 
> Deployment commands are included for reference.

---

## Risk profiles by team

Before defining policies, each team's risk profile must be understood:

| Team | Risk level | Primary concern |
|---|---|---|
| grp-developers | Medium | Access to dev/prod infrastructure, code deployment |
| grp-finance | High | Phishing target, access to financial and payroll data |
| grp-operations | High | VM control, network access, production privileges |
| grp-contractors | Highest | External identity, time-limited engagement, no employment contract |

Higher risk = stricter Conditional Access requirements.

---

## Policy 1 — Require MFA outside trusted locations

**Applies to:** All users  
**Trigger:** Sign-in from outside named trusted locations  
**Control:** Require MFA  

**The reasoning:**  
Sign-ins from within the office network carry lower risk — the device is 
physically present in a controlled environment. Sign-ins from outside — 
home, coffee shop, hotel, foreign country — carry higher risk. MFA adds a 
second verification factor that an attacker who stole a password cannot bypass 
without also having the user's phone.

**Named trusted location:** Contoso office IP range (e.g. 203.0.113.0/24)

**Why not require MFA everywhere?**  
Always-on MFA creates friction that reduces productivity and leads to MFA 
fatigue — users blindly approving prompts. Location-based MFA balances 
security with usability — seamless inside the office, verified outside.

**Break-glass exclusion:**  
One emergency administrator account must be excluded from this policy. 
If Conditional Access misconfiguration locks out all administrators, 
the break-glass account provides recovery access. This account must have:
- A strong 20+ character password
- No MFA registered (by design — emergency use only)
- Access monitored with immediate alerts on any sign-in

---

## Policy 2 — Block legacy authentication protocols

**Applies to:** All users  
**Trigger:** Sign-in using legacy authentication (SMTP, IMAP, POP3, basic auth)  
**Control:** Block access  

**The reasoning:**  
Legacy authentication protocols do not support MFA. An attacker who obtains 
credentials can bypass all MFA requirements by authenticating via SMTP or IMAP 
directly. Microsoft data shows over 99% of password spray attacks use legacy 
authentication.

Blocking legacy authentication is the single highest-impact Conditional Access 
policy — it eliminates an entire class of credential-based attacks.

**Impact on users:**  
Users with legacy email clients (Outlook 2010, Apple Mail with basic auth) 
will lose access. Migration to modern authentication clients is required 
before enabling this policy. Run in report-only mode first to identify 
affected users.

---

## Policy 3 — Operations team — require compliant device

**Applies to:** grp-operations  
**Trigger:** Access to Azure Management portal  
**Control:** Require compliant device (Intune enrolled)  

**The reasoning:**  
Operations staff have VM control, network modification access and production 
privileges. A compromised personal device used to access Azure Management 
creates significant risk — keyloggers, screen capture malware or session 
hijacking could grant an attacker production access.

Requiring a compliant Intune-managed device ensures:
- Device has current OS patches
- Endpoint protection is active
- Device encryption is enabled
- Screen lock is configured

**Why only operations and not all users?**  
Requiring compliant devices for all users creates significant friction and 
onboarding complexity. Operations staff have the highest privilege level — 
the additional friction is justified by the risk reduction. Finance and 
developers access lower-risk resources where device compliance is recommended 
but not enforced at this stage.

---

## Policy 4 — Finance team — block high-risk sign-ins

**Applies to:** grp-finance  
**Trigger:** Sign-in risk = High (detected by Entra ID Identity Protection)  
**Control:** Block access  

**The reasoning:**  
Finance staff are the highest-value phishing targets — they have access to 
payroll, invoices, banking details and financial records. Entra ID Identity 
Protection analyses sign-in patterns and assigns a risk score based on:
- Impossible travel (signed in from Sydney and London within 1 hour)
- Anonymous IP address usage
- Malware-linked IP addresses
- Leaked credentials detected in breach databases

A high-risk sign-in from a finance account must be blocked immediately — 
the potential impact of a compromised finance account justifies the friction 
of blocking and requiring the user to contact IT to verify their identity.

---

## Policy 5 — Contractors — strictest access controls

**Applies to:** grp-contractors  
**Trigger:** Any sign-in  
**Controls:**  
- Require MFA on every sign-in (no trusted location exemption)
- Sign-in frequency: 4 hours (re-authentication required every 4 hours)
- Persistent browser session: disabled (no "stay signed in")

**The reasoning:**  
Contractors are external identities with no employment contract. They 
represent the highest lifecycle risk — their engagement may end without 
IT being notified, they may work for competitors simultaneously, and 
their devices are unmanaged.

MFA on every sign-in regardless of location removes the trusted location 
exemption that permanent employees benefit from. 4-hour session lifetime 
limits the window an attacker has if a contractor session is compromised. 
Disabling persistent sessions prevents contractors from remaining signed 
in indefinitely on unmanaged devices.

---

## Implementation sequence

Deploying Conditional Access incorrectly can lock all users out of Azure.
Always follow this sequence:

```bash
# Step 1 — Deploy in report-only mode first
# Monitor for 2 weeks — identify unintended impacts
# Check sign-in logs: Entra ID → Sign-in logs → filter by policy

# Step 2 — Validate break-glass account works
# Sign in with break-glass account before enabling any policy
# Confirm it is excluded from all policies

# Step 3 — Enable policies one at a time
# Start with least disruptive (MFA outside trusted locations)
# Monitor for 48 hours between each policy enablement
# Have rollback plan ready

# Step 4 — Monitor ongoing
az monitor activity-log alert create \
  --name alert-conditional-access-failure \
  --resource-group rg-iam \
  --condition category=Policy \
  --description "Conditional Access policy change detected"
```

---

## What I would add with more time

- **Number matching MFA** — require users to enter a code shown on the 
  sign-in screen into the authenticator app, preventing MFA fatigue attacks
- **Terms of use policy** — contractors must accept terms of use on every 
  sign-in confirming they understand their access limitations
- **Authentication strength** — require phishing-resistant MFA (FIDO2 security 
  keys) for operations staff accessing production resources
- **Continuous access evaluation** — revoke sessions in real-time when 
  risk is detected mid-session rather than waiting for token expiry
