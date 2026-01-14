# Generated migration for adding workflow_stage field

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('projects', '0007_projectdocument_assigned_to'),
    ]

    operations = [
        migrations.AddField(
            model_name='project',
            name='workflow_stage',
            field=models.CharField(blank=True, help_text='Current stage in the project workflow', max_length=50, null=True),
        ),
    ]

