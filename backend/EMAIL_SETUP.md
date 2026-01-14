# Email Setup Instructions

## Problem
The VPS provider is blocking outbound SMTP connections (ports 587 and 465), which prevents sending emails via Gmail SMTP.

## Solutions

### Option 1: Use SendGrid (Recommended - Free Tier Available)
SendGrid uses HTTP API, not SMTP ports, so it works even when SMTP is blocked.

1. Sign up for SendGrid: https://sendgrid.com (Free tier: 100 emails/day)
2. Create an API key in SendGrid dashboard
3. Add to `.env` file:
   ```
   EMAIL_SERVICE=sendgrid
   SENDGRID_API_KEY=your_sendgrid_api_key_here
   DEFAULT_FROM_EMAIL=auditra.auditing.erp@gmail.com
   ```
4. Restart the Django server

### Option 2: Contact VPS Provider
Ask your VPS provider to unblock outbound SMTP ports 587 and 465 for your server IP.

### Option 3: Use Gmail API (More Complex)
Use Gmail API instead of SMTP. Requires OAuth setup.

## Current Configuration
- Email service: Check `EMAIL_SERVICE` in `.env` (default: 'smtp')
- If using SMTP: Gmail configuration is in `.env`
- If using SendGrid: SendGrid API key is in `.env`

## Testing
After configuration, test email sending:
```bash
python manage.py shell
>>> from django.core.mail import send_mail
>>> from django.conf import settings
>>> send_mail('Test', 'Test message', settings.DEFAULT_FROM_EMAIL, ['your-email@example.com'])
```

