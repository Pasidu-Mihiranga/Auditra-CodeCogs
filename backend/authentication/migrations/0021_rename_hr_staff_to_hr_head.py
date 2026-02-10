from django.db import migrations, models


def migrate_hr_staff_to_hr_head(apps, schema_editor):
    """Convert existing hr_staff roles to hr_head."""
    UserRole = apps.get_model('authentication', 'UserRole')
    UserRole.objects.filter(role='hr_staff').update(role='hr_head')


def migrate_hr_head_to_hr_staff(apps, schema_editor):
    """Reverse: convert hr_head back to hr_staff."""
    UserRole = apps.get_model('authentication', 'UserRole')
    UserRole.objects.filter(role='hr_head').update(role='hr_staff')


class Migration(migrations.Migration):

    dependencies = [
        ('authentication', '0020_set_existing_users_password_changed_true'),
    ]

    operations = [
        # First migrate the data while old choices are still valid
        migrations.RunPython(
            migrate_hr_staff_to_hr_head,
            migrate_hr_head_to_hr_staff,
        ),
        # Then update the field choices
        migrations.AlterField(
            model_name='userrole',
            name='role',
            field=models.CharField(
                choices=[
                    ('admin', 'Admin'),
                    ('coordinator', 'Coordinator'),
                    ('field_officer', 'Field Officer'),
                    ('accessor', 'Accessor'),
                    ('senior_valuer', 'Senior Valuer'),
                    ('md_gm', 'MD/GM'),
                    ('hr_head', 'HR Head'),
                    ('general_employee', 'General Employee'),
                    ('client', 'Client'),
                    ('agent', 'Agent'),
                    ('unassigned', 'Unassigned'),
                ],
                default='unassigned',
                max_length=50,
            ),
        ),
    ]
