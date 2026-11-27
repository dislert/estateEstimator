import { api, session } from './api.js';
import { initializeMap } from './map.js';

const app = document.querySelector('#app');
let map = null, version = 0;

const escape = s => String(s ?? '').replace(/[&<>"']/g, c => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
}[c]));

const field = (label, name, type = 'text', attrs = '') => `
        <label class="field">
        ${label}
        <input name="${name}" type="${type}" ${attrs}>
        </label>
    `;

const select = (label, name, options) => `
        <label class="field">
        ${label}
        <select name="${name}">${options.map(([v, t]) => `
        <option value="${v}">${t}
        </option>
    `).join('')}
        </select>
        </label>
    `;

const head = (tag, title, desc) => `
        <p class="eyebrow">
        ${tag}
        </p>
        <h1>
        ${title}
        </h1>
        <p class="muted">
        ${desc}
        </p>
    `;

const empty = (title, desc, link = '') => `
        <div class="empty">
        <div class="empty-icon" aria-hidden="true">◇</div>
        <h2>
        ${title}
        </h2>
        <p class="muted">
        ${desc}
        </p>
        ${link}
        </div>
    `;

const unavailable = (feature) => `
        <div class="notice">
        ${feature} is not connected yet. No server data is available.</div>
    `;

const link = (href, text, secondary = false) => `
        <a class="btn ${secondary ? 'secondary' : ''}" href="#${href}">${text}
        </a>
    `;

const side = () => `
        <aside class="panel sidebar">
        <a href="#profile">Profile</a>
        <a href="#listings">My properties</a>
        <a href="#requests">Requests</a>
        <a href="#messages">Messages</a>
        <a href="#create">List property</a>
        </aside>
    `;

const layout = (content) => `
        <div class="profile-grid">
        ${side()}
        <section class="panel">
        ${content}
        </section>
        </div>
    `;

function catalog() {
    app.innerHTML = head('Real estate · Virginia, USA', 'Find your next investment', 'Explore residential properties and compare their potential rental returns.') + `
        <form id="filters" class="panel filters">
        ${field('Location', 'location', 'search', 'placeholder="City or ZIP code"')}
        ${select('Property type', 'type', [['', 'Any type'], ['apartment', 'Apartment'], ['house', 'House']])}
        ${field('Min price (USD)', 'min', 'number', 'min="0" placeholder="Any"')}
        ${field('Max price (USD)', 'max', 'number', 'min="0" placeholder="Any"')}
        ${select('Bedrooms', 'beds', [
        ['', 'Any'],
        ['1', '1+'],
        ['2', '2+'],
        ['3', '3+'],
        ['4', '4+']
    ])}
        <button type="submit" disabled>Search</button>
        <details style="grid-column:1/-1">
        <summary>More filters</summary>
        <div class="cols">
        ${field('Minimum area (m²)', 'area', 'number', 'min="0"')}
        ${field('Minimum rooms', 'rooms', 'number', 'min="0"')}
        </div>
        </details>
        </form>
        <div class="split">
        <div id="map" class="map" aria-label="Map of Virginia">
        </div>
        <section class="panel results">
        <div class="actions">
        <h2 style="margin:0">Properties for sale</h2>
        <span class="muted">No data</span>
        </div>
        ${empty('Listings unavailable', 'The property catalog is awaiting its server API. No listings or prices have been fabricated.')}
        ${unavailable('Property search')}
        </section>
        </div>
    `;
    map = initializeMap('map');
}

function auth(kind) {
    const register = kind === 'register';
    app.innerHTML = `
        <section class="panel auth">
        ${head('Your account', register ? 'Create an account' : 'Welcome back', register ? 'Join EstateEstimator.' : 'Sign in to manage your properties and requests.')}
        <form id="auth-form" class="form">
        ${register ? `
        <div class="cols">
        ${field('First name', 'firstName', 'text', 'required maxlength="100" autocomplete="given-name"')}
        ${field('Last name', 'lastName', 'text', 'required maxlength="100" autocomplete="family-name"')}
        </div>
    ` : ''}
        ${field('Email', 'email', 'email', 'required maxlength="255" autocomplete="email"')}
        ${field('Password', 'password', 'password', `required ${register ? 'minlength="8" maxlength="72" autocomplete="new-password"' : 'autocomplete="current-password"'}`)}
        ${register ? select('Account role', 'role', [['buyer', 'Buyer / investor'], ['owner', 'Property owner']]) + select('Gender (optional)', 'gender', [['', 'Prefer not to say'], ['male', 'Male'], ['female', 'Female']]) : ''}
        <div id="error" role="alert" hidden>
        </div>
        <button>
        ${register ? 'Create account' : 'Sign in'}
        </button>
        </form>
        <p style="margin-top:18px">
        ${register ? 'Already registered?' : 'New to EstateEstimator?'}
        <a style="color:var(--accent);font-weight:700" href="#${register ? 'login' : 'register'}">${register ? 'Sign in' : 'Create an account'}
        </a>
        </p>
        ${register ? '' : '<a class="muted" href="#forgot">Forgot password?</a>'}
        </section>
    `;
    document.querySelector('#auth-form').onsubmit = async (e) => {
        e.preventDefault();
        const f = e.currentTarget, b = f.querySelector('button'), error = f.querySelector('#error'), body = Object.fromEntries(new FormData(f));
        if (!body.gender)
            delete body.gender;
        b.disabled = true;
        error.hidden = true;
        try {
            const data = await api('/auth/' + kind, {
                method: 'POST',
                body,
                auth: false
            });
            session.save(data);
            location.hash = 'profile';
        }
        catch (err) {
            error.className = 'error';
            error.hidden = false;
            error.textContent = err.message + (err.fields ? ' Fields: ' + Object.keys(err.fields).join(', ') : '') + (err.trace ? ' Trace ID: ' + err.trace : '') + (err.retry ? ' Retry after ' + err.retry + ' seconds.' : '');
        }
        finally {
            b.disabled = false;
        }
    };
}

async function profile(v) {
    app.innerHTML = head('Account', 'Your workspace', 'Manage your profile and property activity.') + layout('<h2>Profile</h2><p class="muted" id="profile-content">Loading profile…</p>');
    if (!session.token) {
        document.querySelector('#profile-content').innerHTML = 'Sign in to view your account. ' + link('login', 'Sign in');
        return;
    }
    try {
        const u = await api('/users/me');
        if (v !== version)
            return;
        document.querySelector('#profile-content').outerHTML = `
        <div>
        <p>
        <strong>
        ${escape(u.firstName)} ${escape(u.lastName)}
        </strong>
        </p>
        <p>
        ${escape(u.email)}
        </p>
        <p class="muted">Roles: ${escape(u.roles.join(', '))}
        </p>
        <p class="muted">Member since: ${escape(u.createdAt)}
        </p>
        <div class="actions">
        <button id="logout">Sign out</button>
        ${u.roles.includes('admin') ? link('admin', 'Administration', true) : ''}
        </div>
        </div>
    `;
        document.querySelector('#logout').onclick = async (e) => {
            e.currentTarget.disabled = true;
            try {
                await api('/auth/logout', { method: 'POST' });
                session.clear();
                location.hash = 'login';
            }
            catch (err) {
                if (!session.token) {
                    location.hash = 'login';
                    return;
                }
                alert(err.message);
                e.currentTarget.disabled = false;
            }
        };
    }
    catch (err) {
        if (v === version) {
            document.querySelector('#profile-content').textContent = err.message;
            if (!session.token)
                document.querySelector('#profile-content').insertAdjacentHTML('afterend', link('login', 'Sign in'));
        }
    }
}

function compare() {
    app.innerHTML = head('Investment analysis', 'Compare properties', 'Review key metrics side by side before making a decision.') + `
        <section class="panel">
        ${empty('No properties to compare', 'Select properties from the catalog when listings become available.', link('catalog', 'Explore properties'))}
        <div class="table-wrap">
        <table>
        <thead>
        <tr>
        <th>Investment metric</th>
        <th>Selected properties</th>
        </tr>
        </thead>
        <tbody>
        ${[
        'Sale price',
        'Estimated monthly rent',
        'Gross annual yield',
        'Area',
        'Bedrooms',
        'Data source',
        'Methodology',
        'Data date',
        'Territory'
    ].map(x => `
        <tr>
        <td>
        ${x}
        </td>
        <td class="muted">No data</td>
        </tr>
    `).join('')}
        </tbody>
        </table>
        </div>
        </section>
    `;
}

function property() {
    app.innerHTML = head('Property details', 'Property information', 'View listing details and investment analysis.') + `
        <div class="panel">
        ${empty('Property unavailable', 'No property data can be retrieved yet.', link('catalog', 'Back to catalog', true))}
        <h2>Investment overview</h2>
        <div class="metrics">
        ${['Sale price', 'Estimated monthly rent', 'Gross annual yield'].map(x => `
        <div class="metric">
        <small>
        ${x}
        </small>
        <strong>No data</strong>
        </div>
    `).join('')}
        </div>
        <p class="notice">Rental estimates use HUD Fair Market Rents when available. Gross yield excludes expenses, taxes and financing.</p>
        <h2>Regional market history</h2>
        <p class="muted">No data. Regional market history is not the price history of this property.</p>
        <button disabled>Send request</button>
        </div>
    `;
}

function create() {
    app.innerHTML = head('Owner workspace', 'List a property', 'Enter residential property details. Publishing is unavailable until the listings API is implemented.') + `
        <section class="panel wide">
        <form class="form" id="listing-form">
        <h2>Property details</h2>
        ${field('Listing title', 'title', 'text', 'required maxlength="255"')}
        <label class="field">Description<textarea name="description" rows="4"></textarea>
        </label>
        <div class="cols">
        ${select('Property type', 'propertyType', [['house', 'House'], ['apartment', 'Apartment']])}
        ${select('Currency', 'currency', [['USD', 'USD'], ['EUR', 'EUR'], ['GBP', 'GBP']])}
        ${field('Price', 'price', 'number', 'min="0" step="0.01"')}
        ${field('Area (m²)', 'area', 'number', 'min="0" step="0.01"')}
        ${field('Rooms', 'rooms', 'number', 'min="0"')}
        ${field('Bedrooms', 'bedrooms', 'number', 'min="0"')}
        </div>
        <h2>Location</h2>
        <div class="cols">
        ${select('Country', 'country', [['US', 'United States'], ['GB', 'United Kingdom'], ['FR', 'France']])}
        ${field('Region', 'region')}
        ${field('City', 'city')}
        ${field('ZIP / postal code', 'zipCode')}
        ${field('Street', 'street')}
        ${field('House number', 'houseNumber')}
        </div>
        <h2>Photos</h2>
        <label class="field">Select images<input type="file" accept="image/*" multiple disabled>
        </label>
        ${unavailable('Publishing, image upload and draft saving')}
        <div class="actions">
        <button disabled>Save draft</button>
        <button disabled>Publish property</button>
        </div>
        </form>
        </section>
    `;
}

function workspace(route) {
    const content = {
        listings: [
            'My properties',
            'Manage published listings and drafts.',
            'No listings available',
            'The property management API is not available yet.',
            link('create', 'Create property')
        ],
        requests: [
            'Requests',
            'Manage incoming and outgoing property requests.',
            'No request data',
            'Requests cannot be retrieved until the server API is available.',
            ''
        ],
        messages: [
            'Messages',
            'Communicate with buyers and owners about properties.',
            'No conversations available',
            'Chat history will be shown here once the messaging API is available.',
            ''
        ],
        admin: [
            'Administration',
            'Manage users, listings and analytical data.',
            'Administration unavailable',
            'Management endpoints are not implemented yet.',
            ''
        ]
    }[route];
    app.innerHTML = head('Workspace', content[0], content[1]) + layout(`${route === 'requests' ? '<div class="tabs"><button disabled>Incoming</button><button disabled>Outgoing</button></div>' : route === 'admin' ? '<div class="tabs"><button disabled>Users</button><button disabled>Listings</button><button disabled>Data sources</button></div>' : ''}
        ${empty(content[2], content[3], content[4])}`);
}

function render() {
    const v = ++version;
    if (map) {
        map.remove();
        map = null;
    }
    const route = location.hash.slice(1).split('?')[0] || 'catalog';
    document.querySelector('#account').textContent = session.token ? 'My account' : 'Sign in';
    document.querySelector('#account').href = session.token ? '#profile' : '#login';
    document.querySelectorAll('nav a').forEach(a => a.classList.toggle('active', a.getAttribute('href') === '#' + route));
    if (route === 'catalog')
        catalog();
    else if (['login', 'register'].includes(route))
        auth(route);
    else if (route === 'profile')
        profile(v);
    else if (route === 'compare')
        compare();
    else if (route === 'property')
        property();
    else if (route === 'create')
        create();
    else if ([
        'listings',
        'requests',
        'messages',
        'admin'
    ].includes(route))
        workspace(route);
    else if (route === 'forgot')
        app.innerHTML = `
        <section class="panel auth">
        ${head('Account', 'Reset password', 'Password recovery is not available yet.')}
        ${field('Email', 'email', 'email', 'disabled')}
        <p class="notice">The recovery API is not implemented.</p>
        <button disabled>Send reset code</button>
        ${link('login', 'Back to sign in', true)}
        </section>
    `;
    else
        app.innerHTML = empty('Page not found', 'This page does not exist.', link('catalog', 'Explore'));
    window.scrollTo(0, 0);
}
window.addEventListener('hashchange', render);
render();
