from django.db import migrations, models
import django.utils.timezone


class Migration(migrations.Migration):

    dependencies = [
        ('system_logs', '0002_alter_systemlog_action'),
    ]

    operations = [
        migrations.AlterField(
            model_name='systemlog',
            name='timestamp',
            field=models.DateTimeField(default=django.utils.timezone.now, db_index=True),
        ),
    ]
