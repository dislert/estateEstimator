// Same-origin Spring Boot deployment. No mock responses.
export const API_BASE = '/api/v1';
export const session = {
    get token() {
        return sessionStorage.getItem('ee.token');
    },
    save(data) {
        sessionStorage.setItem('ee.token', data.accessToken);
    },
    clear() {
        sessionStorage.removeItem('ee.token');
    }
};

const messages = {
    invalid_credentials: 'Invalid email or password.',
    account_blocked: 'Your account is blocked.',
    email_already_used: 'This email is already registered.',
    unauthorized: 'Please sign in again.',
    forbidden: 'Access denied.',
    validation_error: 'Please check the highlighted fields.',
    malformed_request: 'Invalid request.',
    too_many_requests: 'Too many requests. Please try again later.'
};

export async function api(path, { method = 'GET', body, auth = true } = {}) {
    const headers = { Accept: 'application/json' };
    if (body !== undefined)
        headers['Content-Type'] = 'application/json';
    if (auth && session.token)
        headers.Authorization = `Bearer ${session.token}`;
    let res;
    try {
        res = await fetch(API_BASE + path, {
            method,
            headers,
            body: body === undefined ? undefined : JSON.stringify(body)
        });
    }
    catch {
        throw new Error('Unable to connect to the server.');
    }
    if (res.status === 204)
        return null;
    let data;
    try {
        data = await res.json();
    }
    catch {
        throw new Error(`Server returned an unexpected response (${res.status}).`);
    }
    if (!res.ok) {
        if (auth && res.status === 401)
            session.clear();
        const err = new Error(messages[data.error] || `Request failed (${res.status}).`);
        err.fields = data.fieldErrors;
        err.trace = data.traceId;
        err.retry = res.headers.get('Retry-After');
        throw err;
    }
    return data;
}
