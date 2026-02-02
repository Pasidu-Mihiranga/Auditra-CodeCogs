from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('valuations', '0005_valuation_submitted_report'),
    ]

    operations = [
        migrations.AddField(
            model_name='valuation',
            name='accessor_comments',
            field=models.TextField(blank=True, default='', help_text='Comments from accessor when accepting valuation'),
        ),
    ]
