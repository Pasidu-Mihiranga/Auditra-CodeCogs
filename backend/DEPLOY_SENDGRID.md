# Deploy SendGrid Configuration to VPS

## Quick Steps

### 1. Update .env File on VPS

SSH into your VPS and update the `.env` file:

```bash
ssh root@152.42.240.220
cd /var/www/auditra/backend
nano .env
```

**Add or update these lines:**
```env
SENDGRID_API_KEY=SG.your_actual_api_key_here
DEFAULT_FROM_EMAIL=auditra.auditing.erp@gmail.com
```

**Remove or comment out these SMTP lines (no longer needed):**
```env
# EMAIL_HOST_USER=...
# EMAIL_HOST_PASSWORD=...
# EMAIL_PORT=...
# EMAIL_USE_TLS=...
```

### 2. Pull Latest Code

```bash
cd /var/www/auditra/backend
git pull origin Pasidu
```

### 3. Install SendGrid Package

```bash
cd /var/www/auditra/backend
source venv/bin/activate
pip install sendgrid-django==5.3.0
```

Or install all requirements:
```bash
pip install -r requirements.txt
```

### 4. Restart Django Server

```bash
supervisorctl restart auditra
```

### 5. Test Email Sending

```bash
cd /var/www/auditra/backend
source venv/bin/activate
python manage.py shell
```

Then in Python shell:
```python
from django.core.mail import send_mail
from django.conf import settings

print(f"Using SendGrid API Key: {settings.SENDGRID_API_KEY[:10]}...")
print(f"From Email: {settings.DEFAULT_FROM_EMAIL}")

send_mail(
    'Auditra - SendGrid Test',
    'This is a test email to verify SendGrid is working.',
    settings.DEFAULT_FROM_EMAIL,
    ['your-email@example.com'],  # Replace with your email
    fail_silently=False,
)
```

If successful, you should see no errors. Check your email inbox!

## Verify SendGrid Setup

1. **Check SendGrid Dashboard:**
   - Go to https://app.sendgrid.com
   - Navigate to **Activity** → **Email Activity**
   - You should see the test email being sent

2. **Check Django Logs:**
   ```bash
   tail -f /var/log/supervisor/auditra-stdout.log
   ```

## Troubleshooting

### Error: "SENDGRID_API_KEY not set"
- Make sure `SENDGRID_API_KEY` is in your `.env` file
- Restart the Django server after updating `.env`

### Error: "The from address does not match a verified Sender Identity"
- Go to SendGrid dashboard → Settings → Sender Authentication
- Verify the email address: `auditra.auditing.erp@gmail.com`
- Make sure `DEFAULT_FROM_EMAIL` in `.env` matches the verified email

### Error: "ModuleNotFoundError: No module named 'sendgrid_backend'"
- Run: `pip install sendgrid-django==5.3.0`
- Make sure you're in the virtual environment

## What Changed

✅ **Removed:** SMTP configuration (Gmail SMTP)  
✅ **Added:** SendGrid API configuration  
✅ **Updated:** Email service to use SendGrid backend  
✅ **Added:** Better logging for email sending  

## Benefits

- ✅ Works even when SMTP ports are blocked
- ✅ Better email deliverability
- ✅ Email analytics in SendGrid dashboard
- ✅ Free tier: 100 emails/day
- ✅ No SMTP port configuration needed

