# SendGrid Email Setup Guide

## Overview
This project uses SendGrid for sending emails. SendGrid uses HTTP API instead of SMTP ports, so it works even when SMTP ports are blocked by VPS providers.

## Setup Steps

### 1. Create SendGrid Account
1. Go to https://sendgrid.com
2. Sign up for a free account (100 emails/day free tier)
3. Verify your email address

### 2. Create API Key
1. Log into SendGrid dashboard
2. Go to **Settings** → **API Keys**
3. Click **Create API Key**
4. Name it (e.g., "Auditra Production")
5. Select **Full Access** or **Restricted Access** with "Mail Send" permissions
6. Click **Create & View**
7. **Copy the API key immediately** (you won't be able to see it again!)

### 3. Verify Sender Identity
1. Go to **Settings** → **Sender Authentication**
2. Click **Verify a Single Sender**
3. Fill in the form:
   - **From Email Address**: `auditra.auditing.erp@gmail.com`
   - **From Name**: `Auditra Team`
   - **Reply To**: `auditra.auditing.erp@gmail.com`
   - **Company Address**: Your company address
   - **Website**: Your website (if any)
4. Click **Create**
5. Check your email and click the verification link

**Note:** For production, consider setting up Domain Authentication instead of Single Sender for better deliverability.

### 4. Update Environment Variables

Add to your `.env` file:

```env
SENDGRID_API_KEY=SG.your_api_key_here
DEFAULT_FROM_EMAIL=auditra.auditing.erp@gmail.com
```

**Important:** 
- Replace `SG.your_api_key_here` with your actual SendGrid API key
- The `DEFAULT_FROM_EMAIL` must match the verified sender email in SendGrid

### 5. Install Dependencies

On your VPS:
```bash
cd /var/www/auditra/backend
source venv/bin/activate
pip install -r requirements.txt
```

### 6. Restart Django Server

```bash
supervisorctl restart auditra
```

## Testing

### Test Email Sending
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
    'This is a test email from Auditra',
    settings.DEFAULT_FROM_EMAIL,
    ['your-email@example.com'],
    fail_silently=False,
)
```

### Check SendGrid Dashboard
1. Go to **Activity** in SendGrid dashboard
2. You should see the email being sent
3. Check delivery status

## Troubleshooting

### Error: "The from address does not match a verified Sender Identity"
- Make sure you've verified the sender email in SendGrid
- Check that `DEFAULT_FROM_EMAIL` in `.env` matches the verified email

### Error: "Invalid API key"
- Verify the API key is correct in `.env`
- Make sure there are no extra spaces
- Regenerate the API key if needed

### Emails going to spam
- Set up Domain Authentication instead of Single Sender
- Add SPF and DKIM records to your domain
- Use a professional email address (not Gmail)

### Rate Limits
- Free tier: 100 emails/day
- If you exceed this, upgrade to a paid plan or wait until the next day

## Configuration Files

- **Backend Settings**: `backend/auditra_backend/settings.py`
- **Email Service**: `backend/authentication/services.py`
- **Environment**: `.env` file

## Benefits of SendGrid

✅ Works even when SMTP ports are blocked  
✅ Better deliverability than direct SMTP  
✅ Email analytics and tracking  
✅ Free tier available (100 emails/day)  
✅ No need to manage SMTP credentials  
✅ Built-in spam protection  

