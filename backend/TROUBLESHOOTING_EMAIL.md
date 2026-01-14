# Email Troubleshooting Guide

## Current Issue
SMTP connections to Gmail (port 587) are timing out, even though:
- ✅ Firewall (ufw) allows ports 587 and 465
- ✅ DNS resolution works
- ✅ Network routing appears correct

## Possible Causes

### 1. Cloud Provider Firewall/Security Group
Many VPS providers have a **cloud firewall** or **security group** that's separate from the server's firewall (ufw). This needs to be configured in the provider's dashboard.

**Action Required:**
- Log into your VPS provider's dashboard (DigitalOcean, AWS, etc.)
- Find "Firewall" or "Security Groups" settings
- Add outbound rule: Allow TCP port 587 to any destination
- Add outbound rule: Allow TCP port 465 to any destination
- Apply the rules to your server

### 2. Network-Level Blocking
Some providers block SMTP ports at the network level to prevent spam.

**Action Required:**
- Contact your VPS provider support
- Ask them to unblock outbound SMTP ports 587 and 465 for your server IP: **152.42.240.220**
- Mention you need it for transactional emails (account credentials)

### 3. Alternative Solutions

#### Option A: Use SendGrid (Recommended)
SendGrid uses HTTPS API, not SMTP ports, so it works even when SMTP is blocked.

1. Sign up: https://sendgrid.com (Free: 100 emails/day)
2. Create API key
3. Update `.env`:
   ```
   EMAIL_SERVICE=sendgrid
   SENDGRID_API_KEY=your_api_key
   DEFAULT_FROM_EMAIL=auditra.auditing.erp@gmail.com
   ```

#### Option B: Use Mailgun
Similar to SendGrid, uses HTTP API.

#### Option C: Use AWS SES
If you're on AWS, use SES which works within AWS network.

## Testing Email Configuration

After fixing the issue, test with:
```bash
cd /var/www/auditra/backend
source venv/bin/activate
python manage.py shell
```

```python
from django.core.mail import send_mail
from django.conf import settings

send_mail(
    'Test Email',
    'This is a test',
    settings.DEFAULT_FROM_EMAIL,
    ['your-email@example.com'],
    fail_silently=False,
)
```

## Current Configuration
- **Host:** smtp.gmail.com
- **Port:** 587
- **Encryption:** TLS
- **From:** auditra.auditing.erp@gmail.com

## Next Steps
1. Check cloud provider firewall/security groups
2. Contact VPS provider support if needed
3. Or switch to SendGrid/Mailgun for immediate solution

