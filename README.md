# Azure Zero Trust IAM System — Contoso

This project is about making sure the right people can access the right 
company systems safely, while reducing the chances of mistakes, data leaks, 
fraud, or former workers keeping access they should no longer have. It creates 
clear rules for employees, contractors, and different departments so that 
sensitive information and business systems are better protected without relying 
on manual guesswork from IT staff.

A company would pay for this because security problems, accidental over-access, 
and poor onboarding or offboarding processes can lead to financial loss, 
operational disruption, compliance issues, and reputational damage. A 
well-designed access system makes the business safer, more consistent, easier 
to manage, and more scalable as the company grows.

Built as a portfolio project demonstrating Zero Trust identity and access 
management on Azure.

---

## The Zero Trust Principle

Traditional security said: "You're inside the network therefore I trust you."

Zero Trust says: "Should this identity be trusted right now, for this request, 
under these conditions?"

Every access request is evaluated continuously — not just at login but on every 
request, every session, every resource access. Trust is never assumed. It is 
always verified.

---

## The Problem This Solves

Without an IAM system a company faces five specific risks:

| Risk | Consequence |
|---|---|
| No access control | Anyone can access any resource |
| Over-privileged accounts | One compromised account = full infrastructure access |
| Manual onboarding | Inconsistent access, wrong permissions, day-one delays |
| Forgotten offboarding | Former employees retain access after departure |
| No access reviews | Access creep — people accumulate permissions over time |

This system addresses all five automatically.

---

## Architecture — Five Components
Zero Trust IAM System
│
├── 1. Security Groups        Who belongs together
│   grp-developers            Engineering team
│   grp-finance               Finance and cost reporting
│   grp-operations            Infrastructure management
│   grp-contractors           External — strictest controls
│
├── 2. Custom RBAC Roles      What each group can do
│   VM Operator               Start/stop/restart VMs only
│   Storage Auditor           Read blobs and audit logs only
│   Cost Viewer               Read cost data only
│
├── 3. Role Assignments       WHO + WHAT + WHERE
│   grp-operations → VM Operator → rg-production
│   grp-finance → Cost Viewer → subscription scope
│   grp-finance → Storage Auditor → storage accounts
│
├── 4. Conditional Access     When and how access is permitted
│   Policy 1: MFA outside trusted locations
│   Policy 2: Block legacy authentication
│   Policy 3: Operations — compliant device required
│   Policy 4: Finance — block high-risk sign-ins
│   Policy 5: Contractors — strictest session controls
│
└── 5. Access Reviews         Should this access continue?
Quarterly review of all group memberships
Mandatory contractor review
Automated flagging of disabled accounts
Human decision required for each case
---

## Repository Structure
azure-iam-zero-trust/
├── groups/
│   └── create-groups.sh        Create all security groups
├── roles/
│   ├── vm-operator.json        Custom role — operations team
│   ├── storage-auditor.json    Custom role — finance compliance
│   └── cost-viewer.json        Custom role — finance reporting
├── policies/
│   └── conditional-access-design.md  Zero Trust policy architecture
└── scripts/
├── onboarding.sh           Automate new employee access setup
├── offboarding.sh          Immediate access revocation on departure
└── access-review.sh        Quarterly compliance reporting
---

## Component Deep Dive

### Security Groups

Four groups representing distinct populations with different risk profiles 
and access requirements. Groups are the foundation — all RBAC and Conditional 
Access policies target groups not individuals.

**Why groups not individuals:**
Adding someone to a group gives them everything they need in one action.
Removing them revokes everything in one action. Individual assignments 
multiply with team size — at 50 people you have hundreds of assignments 
to maintain. Groups scale to any team size with zero additional overhead.

**Naming convention:** `grp-[team]` prefix makes groups instantly 
distinguishable from users and service principals in any listing.

---

### Custom RBAC Roles

Three custom roles built on the principle of explicit least privilege — 
listing only the specific Actions permitted rather than granting broad 
categories and carving out exceptions.

**VM Operator — why custom instead of built-in:**
The closest built-in role is Virtual Machine Contributor. It includes 
create and delete VM permissions the operations team should never have.
Custom role grants only start, stop, restart and view — nothing more.

**Cost Viewer — why custom instead of Reader:**
Reader at subscription scope exposes the entire infrastructure blueprint —
VM configurations, network topology, security settings. A compromised 
Reader account gives an attacker a complete map of the Azure environment.
Cost Viewer exposes only billing data — dramatically reduced blast radius 
if the account is compromised.

**Storage Auditor — why both Actions and NotActions:**
Broad read permissions across a storage hierarchy can include unexpected 
sub-actions. NotActions explicitly removes write and delete as a 
defence-in-depth safety net — belt and braces for a compliance role where 
data integrity is critical.

---

### Conditional Access Policies

Five policies implementing Zero Trust enforcement. See 
`policies/conditional-access-design.md` for full design rationale.

> Requires Entra ID P1 licence. Design documented for reference —
> deployment commands included in the design document.

**Risk-based approach — different teams get different controls:**
grp-developers   → MFA outside trusted locations
grp-finance      → MFA + block high-risk sign-ins (phishing target)
grp-operations   → MFA + compliant device required (production access)
grp-contractors  → MFA always + 4-hour session limit (highest risk)
**Always deploy in report-only mode first.** Enabling Conditional Access 
without validating impact can lock users out of Azure. Report-only mode 
runs the policy silently for 2 weeks — identify affected users and resolve 
issues before enforcement begins.

---

### Lifecycle Scripts

Three scripts managing the complete employee lifecycle:

**onboarding.sh — automated access provisioning**
Takes name, username and role as arguments. Creates the user account, adds 
them to the correct security group, verifies membership and outputs a 
checklist of remaining manual steps. Consistent every time — no missed 
permissions, no wrong group assignments.

**offboarding.sh — immediate access revocation**
SECURITY CRITICAL. Disables the account FIRST before removing group 
memberships — this is the correct order. Disabling first closes the 
authentication door immediately. Removing groups while the account is 
still enabled creates a window where the user could authenticate between 
each removal step.

**access-review.sh — quarterly compliance reporting**
Generates a report of all group memberships. Flags disabled accounts 
still retaining group memberships. Gives contractors a mandatory separate 
review section. Produces a checklist of actions for the reviewer.

Human review is required — not automated removal. Automation has no 
business context. An employee on parental leave, a contractor whose 
project was extended — automation would remove their access incorrectly. 
The script generates intelligence. The human makes the judgment call.

---

## How to Deploy

### Prerequisites
- Azure CLI authenticated
- User Administrator role in Entra ID
- Contributor role on target subscription
- Entra ID P1 licence for Conditional Access policies

### Step 1 — Create security groups
```bash
chmod +x groups/create-groups.sh
./groups/create-groups.sh
```

### Step 2 — Create custom roles
```bash
# Replace YOUR-SUBSCRIPTION-ID in each role file first
az role definition create --role-definition roles/vm-operator.json
az role definition create --role-definition roles/storage-auditor.json
az role definition create --role-definition roles/cost-viewer.json
```

### Step 3 — Assign roles to groups
```bash
SUBSCRIPTION_ID=$(az account show --query id --output tsv)

# Operations team — VM Operator on production resource group
az role assignment create \
  --assignee $(az ad group show --group grp-operations --query id --output tsv) \
  --role "VM Operator" \
  --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-production

# Finance team — Cost Viewer at subscription scope
az role assignment create \
  --assignee $(az ad group show --group grp-finance --query id --output tsv) \
  --role "Cost Viewer" \
  --scope /subscriptions/$SUBSCRIPTION_ID
```

### Step 4 — Deploy Conditional Access (P1 required)
See `policies/conditional-access-design.md` for full deployment guide.
Always deploy in report-only mode first — minimum 2 weeks before enforcement.

### Step 5 — Onboard first users
```bash
chmod +x scripts/onboarding.sh scripts/offboarding.sh scripts/access-review.sh

./scripts/onboarding.sh \
  --name "John Smith" \
  --username "jsmith" \
  --role "developer"
```

### Step 6 — Schedule quarterly access reviews
```bash
./scripts/access-review.sh > access-review-$(date +%Y-%m-%d).txt
# Schedule via cron or Azure Automation every 90 days
```

---

## Key Decisions and Tradeoffs

| Decision | Choice | Reason |
|---|---|---|
| Role assignments | Groups not individuals | Scales to any team size, single action for onboarding/offboarding |
| Role definitions | Explicit Actions only | Least privilege — no unexpected permissions from wildcards |
| Offboarding order | Disable before group removal | Closes authentication door immediately — no window between steps |
| Access reviews | Human review not automation | Business context required — automation has no knowledge of leave, role changes |
| Contractor controls | Strictest policies | External identity, no employment contract, highest risk profile |
| Report-only first | Always before enforcement | Validates impact before locking users out |

---

## Business Impact

| Problem | Solution | Impact |
|---|---|---|
| Over-privileged accounts | Custom least-privilege roles | Blast radius of compromised account reduced dramatically |
| Manual onboarding | onboarding.sh | Consistent access in minutes not hours, zero missed permissions |
| Forgotten offboarding | offboarding.sh | Access revoked in seconds not days, eliminates insider threat window |
| Access creep | Quarterly access reviews | Permissions stay current, compliance audit trail maintained |
| Legacy authentication attacks | Conditional Access Policy 2 | Eliminates entire class of credential-based attacks |

---

## What I Would Add With More Time

- **Number matching MFA** — prevents MFA fatigue attacks where users 
  blindly approve push notifications
- **Privileged Identity Management (PIM)** — just-in-time privileged access 
  so admin roles are only active when needed, not permanently assigned
- **Automated licence assignment** — dynamic groups trigger M365 licence 
  assignment automatically on group membership
- **Break-glass account monitoring** — immediate alert when emergency 
  admin account is used
- **Cross-tenant access policies** — for B2B contractor access using 
  their own organisation's identity rather than guest accounts

---

## Learning Context

This project was built alongside AZ-104 certification study as a practical 
application of Azure identity and governance concepts. AI tooling was used 
to accelerate development — all architectural decisions, security tradeoffs 
and implementation choices are understood and documented above.
