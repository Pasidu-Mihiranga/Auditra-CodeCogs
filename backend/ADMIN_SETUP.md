# Admin User Setup

## System Admin

The Auditra system has ONE admin user with permanent admin privileges.

### Admin Credentials

```
Username: admin
Password: admin@auditra2024
```

### Important Notes

1. **Only ONE Admin:** The system admin is the only user with the admin role
2. **Cannot Be Changed:** The admin user's role cannot be modified or removed
3. **Cannot Assign Admin Role:** Admin cannot assign the admin role to other users
4. **Permanent Access:** Admin always has full system access

## Admin Privileges

The admin user can:
- ✅ View all registered users
- ✅ Assign roles to any user (except admin role)
- ✅ Change user roles at any time
- ✅ View system statistics
- ✅ Access admin dashboard

The admin user cannot:
- ❌ Assign admin role to other users
- ❌ Change their own admin role
- ❌ Create multiple admin users

## Security Recommendations

1. **Change Password:** It's recommended to change the default password
   ```bash
   python manage.py changepassword admin
   ```

2. **Keep Credentials Secure:** Only share admin credentials with authorized personnel

3. **Monitor Admin Actions:** All role assignments are logged with admin username and timestamp

## To Change Admin Password

```bash
cd backend
python manage.py changepassword admin
```

Enter new password when prompted.

## Database Structure

The admin user has:
- `username`: admin
- `is_staff`: True
- `is_superuser`: True
- `role`: admin (in UserRole table)

This ensures the admin has both Django admin panel access and app admin privileges.

## Troubleshooting

### If admin user is missing:
```bash
python manage.py create_admin
```

### If admin role is changed accidentally:
```sql
UPDATE user_roles SET role='admin' WHERE user_id=(SELECT id FROM auth_user WHERE username='admin');
```

Or use Django shell:
```bash
python manage.py shell
```
```python
from django.contrib.auth.models import User
admin = User.objects.get(username='admin')
admin.role.role = 'admin'
admin.role.save()
```

## Available Roles for Assignment

Admin can assign these roles to users:
1. Coordinator
2. Field Officer
3. Accessor
4. Senior Valuer
5. MD/GM
6. HR Head
7. General Employee
8. Client
9. Agent

**Note:** "Admin" and "Unassigned" are NOT available for assignment.

