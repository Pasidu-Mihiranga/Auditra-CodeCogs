from django.core.management.base import BaseCommand
from attendance.models import Holiday
from datetime import date


class Command(BaseCommand):
    help = 'Populate Sri Lankan public holidays for the current year'

    def add_arguments(self, parser):
        parser.add_argument(
            '--year',
            type=int,
            default=date.today().year,
            help='Year to populate holidays for (default: current year)',
        )

    def handle(self, *args, **options):
        year = options['year']
        
        # Sri Lankan Public Holidays 2024-2025
        holidays = [
            # Fixed holidays
            ('New Year\'s Day', date(year, 1, 1)),
            ('Tamil Thai Pongal Day', date(year, 1, 15)),
            ('Duruthu Full Moon Poya Day', date(year, 1, 25)),
            ('Independence Day', date(year, 2, 4)),
            ('Navam Full Moon Poya Day', date(year, 2, 24)),
            ('Maha Shivaratri', date(year, 3, 8)),
            ('Medin Full Moon Poya Day', date(year, 3, 25)),
            ('Good Friday', date(year, 3, 29)),
            ('Bak Full Moon Poya Day', date(year, 4, 23)),
            ('May Day', date(year, 5, 1)),
            ('Vesak Full Moon Poya Day', date(year, 5, 23)),
            ('Day following Vesak Full Moon Poya Day', date(year, 5, 24)),
            ('Poson Full Moon Poya Day', date(year, 6, 21)),
            ('Esala Full Moon Poya Day', date(year, 7, 21)),
            ('Nikini Full Moon Poya Day', date(year, 8, 19)),
            ('Binara Full Moon Poya Day', date(year, 9, 17)),
            ('Vap Full Moon Poya Day', date(year, 10, 17)),
            ('Deepavali', date(year, 10, 31)),
            ('Il Full Moon Poya Day', date(year, 11, 15)),
            ('Christmas Day', date(year, 12, 25)),
            ('Unduvap Full Moon Poya Day', date(year, 12, 15)),
        ]
        
        created_count = 0
        updated_count = 0
        
        for name, holiday_date in holidays:
            holiday, created = Holiday.objects.get_or_create(
                date=holiday_date,
                defaults={'name': name, 'is_active': True}
            )
            
            if created:
                created_count += 1
                self.stdout.write(
                    self.style.SUCCESS(f'Created: {name} - {holiday_date}')
                )
            else:
                # Update name if it changed
                if holiday.name != name:
                    holiday.name = name
                    holiday.save()
                    updated_count += 1
                    self.stdout.write(
                        self.style.WARNING(f'Updated: {name} - {holiday_date}')
                    )
        
        self.stdout.write(
            self.style.SUCCESS(
                f'\nSuccessfully processed {len(holidays)} holidays. '
                f'Created: {created_count}, Updated: {updated_count}'
            )
        )

