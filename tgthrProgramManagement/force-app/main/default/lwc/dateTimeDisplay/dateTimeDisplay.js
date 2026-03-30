const MOUNTAIN_TIMEZONE = 'America/Denver';

function parseDateValue(value) {
    if (!value) {
        return null;
    }

    if (value instanceof Date) {
        return Number.isNaN(value.getTime()) ? null : value;
    }

    if (typeof value === 'string') {
        const trimmed = value.trim();
        const dateOnlyMatch = trimmed.match(/^(\d{4})-(\d{2})-(\d{2})$/);
        if (dateOnlyMatch) {
            const year = Number(dateOnlyMatch[1]);
            const month = Number(dateOnlyMatch[2]) - 1;
            const day = Number(dateOnlyMatch[3]);
            // Noon UTC avoids cross-day shifts when formatting in US timezones.
            return new Date(Date.UTC(year, month, day, 12, 0, 0));
        }
    }

    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
}

export function formatDateOnlyMountain(value, options = {}) {
    const parsed = parseDateValue(value);
    if (!parsed) {
        return null;
    }

    return new Intl.DateTimeFormat('en-US', {
        timeZone: MOUNTAIN_TIMEZONE,
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        ...options
    }).format(parsed);
}

export function formatDateTimeMountain(value, options = {}) {
    const parsed = parseDateValue(value);
    if (!parsed) {
        return null;
    }

    return new Intl.DateTimeFormat('en-US', {
        timeZone: MOUNTAIN_TIMEZONE,
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        ...options
    }).format(parsed);
}

export function getMountainTimeZoneLabel() {
    return 'MT';
}
