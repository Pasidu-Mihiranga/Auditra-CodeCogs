import hashlib
import threading
from django.utils import timezone
from .models import SystemLog

GENESIS_HASH = '0' * 64
_lock = threading.Lock()


def log_action(action, user=None, description='', category='system', target_user=None, ip_address=None, metadata=None):
    with _lock:
        last = SystemLog.objects.order_by('-block_index').first()
        block_index = (last.block_index + 1) if last else 0
        previous_hash = last.current_hash if last else GENESIS_HASH

        log = SystemLog(
            block_index=block_index,
            action=action,
            category=category,
            user=user,
            target_user=target_user,
            description=description,
            ip_address=ip_address,
            metadata=metadata,
            previous_hash=previous_hash,
            timestamp=timezone.now(),
        )
        log.current_hash = log.compute_hash()
        log.save()
        return log


def verify_chain():
    logs = SystemLog.objects.order_by('block_index')
    total = logs.count()
    if total == 0:
        return {'is_valid': True, 'total_blocks': 0, 'broken_at': None, 'message': 'No logs to verify.'}

    previous_hash = GENESIS_HASH
    for log in logs.iterator():
        if log.previous_hash != previous_hash:
            return {
                'is_valid': False, 'total_blocks': total,
                'broken_at': log.block_index,
                'message': f'Chain broken at block {log.block_index}: previous_hash mismatch.',
            }
        expected = log.compute_hash()
        if log.current_hash != expected:
            return {
                'is_valid': False, 'total_blocks': total,
                'broken_at': log.block_index,
                'message': f'Chain broken at block {log.block_index}: hash mismatch (data tampered).',
            }
        previous_hash = log.current_hash

    return {'is_valid': True, 'total_blocks': total, 'broken_at': None, 'message': f'Chain integrity verified. All {total} blocks are valid.'}


def get_client_ip(request):
    xff = request.META.get('HTTP_X_FORWARDED_FOR')
    if xff:
        return xff.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR')
