/* Movies for webOS TV. The optional local config is excluded from Git. */
(function () {
  'use strict';

  const API = 'https://api.themoviedb.org/3';
  const IMAGE = 'https://image.tmdb.org/t/p/';
  const SECTIONS = [
    ['Trending', '/trending/all/day'],
    ['Now Playing Movies', '/movie/now_playing'],
    ['Popular TV Shows', '/tv/popular'],
    ['Popular Movies', '/movie/popular'],
    ['Top Rated TV Shows', '/tv/top_rated'],
    ['Top Rated Movies', '/movie/top_rated']
  ];
  const SERVERS = [
    ['MoviesAPI', 'https://moviesapi.to'],
    ['VidFast', 'https://vidfast.vc'],
    ['VidPhantom', 'https://vidphantom.com'],
    ['VidSrc', 'https://vidsrc.sh/embed'],
    ['Rive Stream', 'https://www.rivestream.app/embed/agg'],
    ['VidSpark', 'https://vidspark.to'],
    ['VidLink', 'https://vidlink.pro'],
    ['CineSrc', 'https://cinesrc.st/embed'],
    ['111movies', 'https://111movies.net']
  ];
  const STORE = 'movies.lg.v1';
  const empty = { token: window.LG_TMDB_TOKEN || '', adult: false, server: 'MoviesAPI', homeFilter: 'All',
    expanded: {}, favorites: [], history: [], collections: [] };
  let saved;
  try { saved = JSON.parse(localStorage.getItem(STORE) || '{}'); } catch (_) { saved = {}; }
  const data = Object.assign({}, empty, saved);
  if (!data.token && window.LG_TMDB_TOKEN) data.token = window.LG_TMDB_TOKEN;
  const state = { tab: 'Home', screen: 'main', returnScreen: 'main', returnTab: 'Home',
    collectionId: null, item: null, detail: null, season: null, episodes: [], episode: null,
    player: false, sections: {}, searchQuery: '', searchResults: [], searching: false,
    libraryFilter: 'All', loading: false, notice: '', unlocked: {}, modal: null };
  const app = document.getElementById('app');
  const dialogRoot = document.getElementById('dialog-root');
  let modalReturnFocus = null;

  function persist() { localStorage.setItem(STORE, JSON.stringify(data)); }
  function esc(value) { return String(value == null ? '' : value).replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch])); }
  function attr(value) { return esc(value); }
  function title(item) { return item.title || item.name || 'Untitled'; }
  function type(item) { return item.media_type || (item.first_air_date ? 'tv' : 'movie'); }
  function key(item) { return type(item) + ':' + item.id; }
  function image(path, size) { return path && /^\/[a-zA-Z0-9._/-]+$/.test(path) ? IMAGE + (size || 'w500') + path : ''; }
  function year(item) { return (item.release_date || item.first_air_date || '').slice(0, 4); }
  function isAdult(item) { return Boolean(item.adult); }
  function allowed(item) { return ['movie','tv','person'].includes(type(item)) && (data.adult || !isAdult(item)); }
  function notice(message) { state.notice = message; render(); }
  function btn(label, action, value, extra) {
    return `<button type="button" class="pill ${extra || ''}" data-action="${attr(action)}" data-value="${attr(value == null ? '' : value)}">${esc(label)}</button>`;
  }
  function poster(item, size) {
    const src = image(item.poster_path, size);
    return src ? `<img src="${attr(src)}" alt="" loading="lazy">` : '<div class="poster-fallback">MOVIES</div>';
  }
  function card(item, action, payload) {
    return `<button type="button" class="poster-card" data-action="${attr(action || 'detail')}" data-value="${attr(payload || key(item))}" aria-label="${attr(title(item))}">
      <span class="poster-image">${poster(item)}<span class="type-badge">${type(item) === 'tv' ? 'TV' : type(item) === 'person' ? 'PERSON' : 'MOVIE'}</span></span>
      <span class="poster-name">${esc(title(item))}</span></button>`;
  }
  function findItem(value) {
    const items = [].concat(...Object.values(state.sections).map(s => s.items || []), state.searchResults, data.favorites, data.history, state.detail ? [state.detail] : []);
    return items.find(item => key(item) === value);
  }
  async function request(path, params) {
    if (!data.token.trim()) throw new Error('Add your TMDB API Read Access Token in Settings.');
    const query = new URLSearchParams(Object.assign({ language: 'en-US' }, params || {}));
    const response = await fetch(API + path + '?' + query.toString(), {
      headers: { Authorization: 'Bearer ' + data.token.trim(), accept: 'application/json' }
    });
    if (!response.ok) {
      if (response.status === 401) throw new Error('TMDB rejected the token. Check it in Settings.');
      throw new Error('TMDB request failed (' + response.status + ').');
    }
    return response.json();
  }
  function normalize(raw, knownType) {
    return Object.assign({}, raw, { media_type: knownType || raw.media_type });
  }
  async function loadHome(force) {
    if (!data.token.trim()) return render();
    SECTIONS.forEach(([name]) => {
      if (force || !state.sections[name]) state.sections[name] = { items: [], loading: true, error: '' };
    });
    render();
    await Promise.all(SECTIONS.map(async ([name, path], index) => {
      const section = state.sections[name];
      if (!section.loading) return;
      try {
        const result = await request(path, index === 0 ? {} : { page: 1 });
        const knownType = index === 0 ? null : ([1, 3, 5].includes(index) ? 'movie' : 'tv');
        const seen = new Set();
        section.items = (result.results || []).map(raw => normalize(raw, knownType)).filter(item => {
          const id = key(item);
          if (!allowed(item) || seen.has(id)) return false;
          seen.add(id); return true;
        });
        section.error = '';
      } catch (error) { section.error = error.message; }
      section.loading = false;
      if (state.screen === 'main' && state.tab === 'Home') render(true);
    }));
  }
  async function search(query) {
    state.searchQuery = query.trim();
    if (!state.searchQuery) { state.searchResults = []; return render(); }
    state.searching = true; render();
    try {
      const result = await request('/search/multi', { query: state.searchQuery, include_adult: data.adult, page: 1 });
      state.searchResults = (result.results || []).filter(allowed);
    } catch (error) { notice(error.message); }
    state.searching = false; render();
  }
  async function resolveItem(item) {
    const mediaType = type(item);
    const result = await request('/' + mediaType + '/' + item.id);
    return normalize(result, mediaType);
  }
  async function openDetail(item, fromCollection) {
    if (!item) return;
    state.returnScreen = fromCollection ? 'collection' : 'main';
    state.returnTab = state.tab;
    state.loading = true; render();
    try {
      state.detail = await resolveItem(item);
      state.screen = 'detail'; state.player = false; state.episode = null;
      state.season = null; state.episodes = [];
      if (type(state.detail) === 'tv') {
        const seasons = state.detail.seasons || [];
        const firstRegular = seasons.find(s => s.season_number > 0);
        state.season = firstRegular ? firstRegular.season_number : seasons.length ? seasons[0].season_number : null;
        const prior = item.season;
        if (prior != null) state.season = prior;
        if (state.season != null) await loadSeason(state.season, item.episode);
      }
    } catch (error) { state.notice = error.message; }
    state.loading = false; render();
  }
  async function loadSeason(number, priorEpisode) {
    state.season = Number(number); state.episode = null; state.episodes = []; render();
    try {
      const result = await request('/tv/' + state.detail.id + '/season/' + state.season);
      state.episodes = result.episodes || [];
      if (priorEpisode != null) state.episode = state.episodes.find(e => e.episode_number === Number(priorEpisode)) || null;
    } catch (error) { state.notice = error.message; }
    render();
  }
  function favorite(item) { return data.favorites.some(f => key(f) === key(item)); }
  function toggleFavorite(item) {
    data.favorites = favorite(item) ? data.favorites.filter(f => key(f) !== key(item)) : [summary(item), ...data.favorites];
    persist(); render(true);
  }
  function summary(item) {
    return { id: item.id, media_type: type(item), title: title(item), poster_path: item.poster_path || null,
      release_date: item.release_date || null, first_air_date: item.first_air_date || null };
  }
  function recordWatch(item, season, episode) {
    const watched = Object.assign(summary(item), { season: season == null ? null : season,
      episode: episode == null ? null : episode, watchedAt: Date.now() });
    const watchKey = key(watched) + ':' + watched.season + ':' + watched.episode;
    data.history = [watched, ...data.history.filter(x => key(x) + ':' + x.season + ':' + x.episode !== watchKey)].slice(0, 200);
    persist();
  }
  function serverUrl() {
    const base = (SERVERS.find(s => s[0] === data.server) || SERVERS[0])[1];
    if (data.server === 'Rive Stream') {
      const id = state.detail.id;
      if (type(state.detail) === 'movie') return base + '?type=movie&id=' + id;
      return base + '?type=tv&id=' + id + '&season=' + state.season + '&episode=' + state.episode.episode_number;
    }
    if (type(state.detail) === 'movie') return base + '/movie/' + state.detail.id;
    if (data.server === 'CineSrc') return base + '/tv/' + state.detail.id + '?s=' + state.season + '&e=' + state.episode.episode_number;
    return base + '/tv/' + state.detail.id + '/' + state.season + '/' + state.episode.episode_number;
  }
  function serverPicker() {
    return `<div class="server-picker" aria-label="Playback server">${SERVERS.map(([name]) => btn(name, 'server', name, data.server === name ? 'selected' : '')).join('')}</div>`;
  }
  function nav() {
    return `<aside class="sidebar"><div class="brand">MOVIES<span>LG TV</span></div><nav aria-label="Main menu">${['Home','Library','History','Settings','Search'].map((tab, i) =>
      `<button class="nav-item ${state.tab === tab ? 'selected' : ''}" data-action="tab" data-value="${tab}"><span class="nav-icon">${['⌂','▤','↺','⚙','⌕'][i]}</span>${tab}</button>`).join('')}</nav></aside>`;
  }
  function filters(selected, action) {
    return '<div class="filter-group">' + ['All', 'TV', 'Movies'].map(v => btn(v, action, v, selected === v ? 'selected' : '')).join('') + '</div>';
  }
  function home() {
    if (!data.token.trim()) return `<div class="empty large"><h2>Connect TMDB</h2><p>Add your TMDB API Read Access Token in Settings to load movies and TV shows.</p>${btn('Open Settings','tab','Settings','primary')}</div>`;
    return `<div class="page-heading"><h1>Home</h1>${filters(data.homeFilter, 'home-filter')}</div><div class="sections">${SECTIONS.filter(([name]) =>
      data.homeFilter === 'All' || name === 'Trending' || (data.homeFilter === 'TV' ? name.includes('TV') : name.includes('Movies'))).map(([name]) => {
      const section = state.sections[name] || { loading: true, items: [] };
      const expanded = data.expanded[name] !== false;
      const items = section.items.filter(item => name !== 'Trending' || data.homeFilter === 'All' ||
        (data.homeFilter === 'TV' ? type(item) === 'tv' : type(item) === 'movie'));
      return `<section class="discovery"><button class="section-heading" data-action="expand" data-value="${attr(name)}" aria-expanded="${expanded}"><span>${expanded ? '⌄' : '›'}</span>${esc(name === 'Trending' ? 'Trending Today' : name)}</button>${expanded ?
        section.loading ? '<p class="muted">Loading titles…</p>' : section.error ? `<p class="muted">${esc(section.error)} ${btn('Retry','retry','','small')}</p>` :
        items.length ? `<div class="poster-grid">${items.map(item => card(item)).join('')}</div>` : '<p class="muted">No titles available.</p>' : ''}</section>`;
    }).join('')}</div>`;
  }
  function library() {
    const favorites = data.favorites.filter(item => state.libraryFilter === 'All' || (state.libraryFilter === 'TV' ? type(item) === 'tv' : type(item) === 'movie'));
    return `<div class="page-heading"><h1>Library</h1>${btn('+ New Collection','new-collection')}${filters(state.libraryFilter, 'library-filter')}</div>
      <section><h2>Favorites</h2>${favorites.length ? `<div class="poster-grid">${favorites.map(item => card(item)).join('')}</div>` : '<p class="muted">Movies and shows you favorite will show up here.</p>'}</section>
      <section><h2>Collections</h2>${data.collections.length ? `<div class="poster-grid">${data.collections.map(c => `<button class="poster-card" data-action="open-collection" data-value="${attr(c.id)}"><span class="poster-image collection-cover">${c.hideCover || !c.items.length ? '▤' : poster(c.items[0])}</span><span class="poster-name">${esc(c.name)} ${c.pinHash ? '🔒' : ''}</span></button>`).join('')}</div>` : '<p class="muted">Create a collection to organize movies and shows.</p>'}</section>`;
  }
  function history() {
    return `<div class="page-heading"><h1>History</h1></div>${data.history.length ? `<div class="list">${data.history.map((item, index) => `<div class="list-row"><button class="row-main" data-action="history-detail" data-value="${index}">${poster(item, 'w185')}<span><strong>${esc(title(item))}</strong><small>${item.season == null ? 'Movie' : 'Season ' + item.season + ' · Episode ' + item.episode} · ${new Date(item.watchedAt).toLocaleDateString()}</small></span></button>${btn('Remove','remove-history',index,'small')}</div>`).join('')}</div>` : '<div class="empty"><h2>No Watch History</h2><p>Movies and episodes you watch will show up here.</p></div>'}`;
  }
  function searchPage() {
    return `<div class="page-heading"><h1>Search</h1></div><form id="search-form" class="search-form"><input name="query" aria-label="Search movies and TV" placeholder="Search movies and TV shows" value="${attr(state.searchQuery)}"><button class="pill primary">Search</button></form>
      ${state.searching ? '<p class="muted">Searching…</p>' : state.searchResults.length ? `<div class="list">${state.searchResults.map(item => `<div class="list-row"><button class="row-main" data-action="detail" data-value="${attr(key(item))}">${poster(item, 'w185')}<span><strong>${esc(title(item))}</strong><small>${type(item) === 'tv' ? 'TV Show' : type(item) === 'person' ? 'Person' : 'Movie'} · ${esc(year(item))}</small><span class="row-overview">${esc(item.overview || '')}</span></span></button>${type(item) === 'person' ? '' : btn(favorite(item) ? '★' : '☆','favorite',key(item),'small') + btn('▤','collection-picker',key(item),'small')}</div>`).join('')}</div>` : '<div class="empty"><h2>Find something to watch</h2><p>Search movies, TV shows, and people.</p></div>'}`;
  }
  function settings() {
    return `<div class="page-heading"><h1>Settings</h1></div><section class="settings"><h2>TMDB</h2><p>The API Read Access Token comes from the local build config or is saved on this TV.</p>
      <form id="token-form"><label for="token">API Read Access Token</label><div class="form-row"><input id="token" name="token" type="password" value="${attr(data.token)}" autocomplete="off" spellcheck="false"><button class="pill primary">Save</button></div></form>
      <h2>Discovery</h2>${btn('Include Adult Content: ' + (data.adult ? 'On' : 'Off'),'adult','','')}
      <h2>Playback</h2><p>Choose a server on the detail or player screen. Provider pages are embedded without a sandbox because some players reject it.</p>
      <p class="muted">Playback on webOS cannot use the iOS WebKit network blocking rules. This product uses the TMDB API but is not endorsed or certified by TMDB.</p></section>`;
  }
  function detail() {
    const item = state.detail;
    if (!item) return '<div class="empty">Title unavailable.</div>';
    if (state.player) return player();
    const tv = type(item) === 'tv';
    return `<div class="detail"><div class="toolbar">${btn('‹ Back','back')}${type(item) === 'person' ? '' : btn(favorite(item) ? '★ Favorited' : '☆ Favorite','favorite',key(item), favorite(item) ? 'selected' : '') + btn('▤ Collections','collection-picker',key(item))}<span class="toolbar-spacer"></span>${type(item) === 'person' ? '' : `<span class="muted">Server</span>${serverPicker()}`}</div>
      <div class="hero" style="${image(item.backdrop_path || item.poster_path, 'original') ? `background-image:linear-gradient(90deg,#11151e 10%,rgba(17,21,30,.75) 55%,rgba(17,21,30,.2)),url('${attr(image(item.backdrop_path || item.poster_path, 'original'))}')` : ''}">
        <div class="hero-content"><span class="eyebrow">${tv ? 'TV SHOW' : type(item) === 'person' ? 'PERSON' : 'MOVIE'} ${esc(year(item))}</span><h1>${esc(title(item))}</h1><p>${esc(item.overview || (type(item) === 'person' ? 'People pages are not available yet.' : 'No overview available.'))}</p>${tv || type(item) === 'person' ? '' : btn('▶ Play Movie','play','','primary')}</div></div>
      ${tv ? `<section><h2>Seasons</h2><div class="chip-row">${(item.seasons || []).map(s => btn('Season ' + s.season_number,'season',s.season_number, state.season === s.season_number ? 'selected' : '')).join('')}</div><h2>Episodes</h2>${state.episodes.length ? `<div class="episode-grid">${state.episodes.map(e => `<button class="episode" data-action="episode" data-value="${e.episode_number}"><span>EPISODE ${e.episode_number}</span><strong>${esc(e.name || 'Episode ' + e.episode_number)}</strong><small>${esc(e.overview || 'Select to watch')}</small></button>`).join('')}</div>` : '<p class="muted">No episodes available for this season.</p>'}</section>` : ''}</div>`;
  }
  function player() {
    const item = state.detail;
    const label = type(item) === 'tv' ? `S${state.season} E${state.episode.episode_number} · ${state.episode.name || ''}` : 'Movie';
    return `<div class="player"><div class="player-toolbar">${btn('‹ Details','close-player')}${btn('↻ Reload','reload-player')}${type(item) === 'tv' ? btn('ⓘ Episode Info','episode-info') : ''}<strong>${esc(title(item))} <span>· ${esc(label)}</span></strong><small>Use Magic Remote pointer inside the player</small></div><div class="player-source-row"><span class="muted">Server</span>${serverPicker()}</div><iframe id="player-frame" title="${attr(title(item))} player" src="${attr(serverUrl())}" allow="autoplay; fullscreen; encrypted-media; picture-in-picture" allowfullscreen></iframe></div>`;
  }
  function collectionPage() {
    const c = data.collections.find(x => x.id === state.collectionId);
    if (!c) return '<div class="empty">Collection unavailable.</div>';
    if (c.pinHash && !state.unlocked[c.id]) return `<div class="collection-page">${btn('‹ Library','back')}<div class="empty large"><h1>${esc(c.name)}</h1><p>This collection is locked.</p>${btn('Enter PIN','unlock',c.id,'primary')}</div></div>`;
    return `<div class="collection-page"><div class="page-heading">${btn('‹ Library','back')}<h1>${esc(c.name)}</h1><span class="toolbar-spacer"></span>${btn(c.hideCover ? 'Show Cover' : 'Hide Cover','cover',c.id)}${btn(c.pinHash ? 'Change PIN' : 'Set PIN','set-pin',c.id)}${c.pinHash ? btn('Remove PIN','remove-pin',c.id) : ''}</div>
      ${c.items.length ? `<div class="poster-grid">${c.items.map(item => `<div>${card(item,'collection-detail',key(item))}${btn('Remove','remove-collection-item',key(item),'small')}</div>`).join('')}</div>` : '<div class="empty"><h2>No Titles Yet</h2><p>Add movies or shows from Search or a detail page.</p></div>'}</div>`;
  }
  function render(keepFocus) {
    const active = keepFocus && document.activeElement && document.activeElement.dataset ? [document.activeElement.dataset.action, document.activeElement.dataset.value] : null;
    app.innerHTML = state.screen === 'main' ? nav() + `<main class="content">${state.loading ? '<p class="loading">Loading…</p>' : ''}${state.notice ? `<div class="notice">${esc(state.notice)} ${btn('Dismiss','dismiss','','small')}</div>` : ''}${({Home:home,Library:library,History:history,Settings:settings,Search:searchPage})[state.tab]()}</main>` :
      `<main class="full-content">${state.loading ? '<p class="loading">Loading…</p>' : ''}${state.notice ? `<div class="notice">${esc(state.notice)} ${btn('Dismiss','dismiss','','small')}</div>` : ''}${state.screen === 'detail' ? detail() : collectionPage()}</main>`;
    if (active) {
      const target = Array.from(app.querySelectorAll('[data-action]')).find(el => el.dataset.action === active[0] && el.dataset.value === active[1]);
      if (target) { target.focus({ preventScroll: true }); return; }
    }
    const first = app.querySelector(state.screen === 'main' ? '.nav-item.selected' : 'button, input, select');
    if (first && document.activeElement === document.body) first.focus();
  }
  function closeModal() {
    state.modal = null; dialogRoot.innerHTML = '';
    const target = modalReturnFocus && document.contains(modalReturnFocus) ? modalReturnFocus : app.querySelector('button');
    modalReturnFocus = null;
    if (target) target.focus();
  }
  function modal(titleText, body, onSubmit) {
    modalReturnFocus = document.activeElement;
    state.modal = onSubmit;
    dialogRoot.innerHTML = `<div class="modal-backdrop"><form id="modal-form" class="modal"><h2>${esc(titleText)}</h2>${body}<div class="modal-actions">${btn('Cancel','cancel-modal','','') }<button class="pill primary" type="submit">Continue</button></div></form></div>`;
    dialogRoot.querySelector('input,button').focus();
  }
  function collection() { return data.collections.find(c => c.id === state.collectionId); }
  function newCollection(item) {
    modal('New Collection', '<label>Name<input name="name" maxlength="60" required autocomplete="off"></label>', form => {
      const name = form.elements.name.value.trim(); if (!name) return;
      const c = { id: String(Date.now()) + '-' + Math.random().toString(36).slice(2), name, items: item ? [summary(item)] : [], hideCover: false, pinSalt: null, pinHash: null };
      data.collections.push(c); persist(); closeModal(); render();
    });
  }
  async function pinHash(salt, pin) {
    if (!window.crypto || !window.crypto.subtle) throw new Error('Secure PIN storage is unavailable on this webOS version.');
    const bytes = new TextEncoder().encode(salt + ':' + pin);
    const digest = await crypto.subtle.digest('SHA-256', bytes);
    return Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, '0')).join('');
  }
  function pinDialog(c, operation, next) {
    const prompt = operation === 'unlock' ? 'Unlock ' + c.name : operation === 'remove' ? 'Remove PIN' : c.pinHash ? 'Change PIN' : 'Set PIN';
    const needsCurrent = operation === 'set' && Boolean(c.pinHash);
    modal(prompt, `${needsCurrent ? '<label>Current PIN<input name="current" type="password" inputmode="numeric" pattern="[0-9]{4}" maxlength="4" required></label>' : ''}<label>${operation === 'unlock' ? 'PIN' : operation === 'remove' ? 'Confirm PIN' : 'New 4-digit PIN'}<input name="pin" type="password" inputmode="numeric" pattern="[0-9]{4}" maxlength="4" required></label><p id="pin-error" class="error"></p>`, async form => {
      try {
        const pin = form.elements.pin.value;
        const current = needsCurrent ? form.elements.current.value : pin;
        if (c.pinHash && await pinHash(c.pinSalt, current) !== c.pinHash) throw new Error('Incorrect PIN.');
        if (operation === 'unlock') { state.unlocked[c.id] = true; closeModal(); render(); if (next) next(); return; }
        if (operation === 'remove') { c.pinSalt = null; c.pinHash = null; delete state.unlocked[c.id]; }
        else {
          c.pinSalt = Array.from(crypto.getRandomValues(new Uint8Array(16))).map(b => b.toString(16).padStart(2,'0')).join('');
          c.pinHash = await pinHash(c.pinSalt, pin); state.unlocked[c.id] = true;
        }
        persist(); closeModal(); render(); if (next) next();
      } catch (error) { dialogRoot.querySelector('#pin-error').textContent = error.message; }
    });
  }
  function picker(item) {
    modalReturnFocus = document.activeElement;
    const rows = data.collections.map(c => `<button type="button" class="picker-row" data-action="pick-collection" data-value="${attr(c.id)}">${c.items.some(x => key(x) === key(item)) ? '✓ ' : ''}${esc(c.name)} ${c.pinHash ? '🔒' : ''}</button>`).join('');
    dialogRoot.innerHTML = `<div class="modal-backdrop"><div class="modal"><h2>Collections</h2>${rows || '<p>No collections yet.</p>'}<div class="modal-actions">${btn('Cancel','cancel-modal')}${btn('New Collection','picker-new','','primary')}</div></div></div>`;
    state.modal = { picker: item }; dialogRoot.querySelector('button').focus();
  }
  function handleAction(action, value) {
    const item = findItem(value);
    switch (action) {
      case 'tab': state.screen = 'main'; state.tab = value; state.notice = ''; render(); if (value === 'Home') loadHome(); break;
      case 'home-filter': data.homeFilter = value; persist(); render(true); break;
      case 'library-filter': state.libraryFilter = value; render(true); break;
      case 'expand': data.expanded[value] = data.expanded[value] === false; persist(); render(true); break;
      case 'retry': loadHome(true); break;
      case 'dismiss': state.notice = ''; render(); break;
      case 'detail': openDetail(item); break;
      case 'history-detail': openDetail(data.history[Number(value)]); break;
      case 'favorite': if (item) toggleFavorite(item); break;
      case 'remove-history': data.history.splice(Number(value), 1); persist(); render(); break;
      case 'new-collection': newCollection(); break;
      case 'collection-picker': if (item) picker(item); break;
      case 'picker-new': { const picked = state.modal.picker; newCollection(picked); break; }
      case 'pick-collection': {
        const picked = state.modal.picker; const c = data.collections.find(x => x.id === value);
        if (!c) break;
        const toggle = () => { c.items = c.items.some(x => key(x) === key(picked)) ? c.items.filter(x => key(x) !== key(picked)) : [...c.items, summary(picked)]; persist(); picker(picked); };
        if (c.pinHash && !state.unlocked[c.id]) pinDialog(c, 'unlock', toggle); else toggle(); break;
      }
      case 'open-collection': state.collectionId = value; state.screen = 'collection'; render(); break;
      case 'collection-detail': { const c = collection(); openDetail(c && c.items.find(x => key(x) === value), true); break; }
      case 'remove-collection-item': { const c = collection(); c.items = c.items.filter(x => key(x) !== value); persist(); render(); break; }
      case 'cover': { const c = collection(); c.hideCover = !c.hideCover; persist(); render(); break; }
      case 'unlock': pinDialog(collection(), 'unlock'); break;
      case 'set-pin': pinDialog(collection(), 'set'); break;
      case 'remove-pin': pinDialog(collection(), 'remove'); break;
      case 'season': loadSeason(value); break;
      case 'episode': state.episode = state.episodes.find(e => e.episode_number === Number(value)); state.player = true; recordWatch(state.detail, state.season, state.episode.episode_number); render(); break;
      case 'play': state.player = true; recordWatch(state.detail); render(); break;
      case 'close-player': state.player = false; render(); break;
      case 'reload-player': { const frame = document.getElementById('player-frame'); if (frame) frame.src = serverUrl(); break; }
      case 'server': data.server = value; persist(); render(true); break;
      case 'episode-info': modal(state.episode.name || 'Episode ' + state.episode.episode_number, `<p>${esc(state.episode.overview || 'No episode overview is available.')}</p>`, closeModal); break;
      case 'back': back(); break;
      case 'adult': data.adult = !data.adult; persist(); render(true); if (state.tab === 'Home') loadHome(true); break;
      case 'cancel-modal': closeModal(); break;
    }
  }
  function back() {
    if (state.modal) return closeModal();
    if (state.screen === 'detail') {
      if (state.player) { state.player = false; return render(); }
      state.screen = state.returnScreen; state.tab = state.returnTab; state.detail = null; render(); return;
    }
    if (state.screen === 'collection') { delete state.unlocked[state.collectionId]; state.screen = 'main'; state.tab = 'Library'; render(); return; }
    if (state.tab !== 'Home') { state.tab = 'Home'; render(); return; }
    if (window.webOS && typeof window.webOS.platformBack === 'function') window.webOS.platformBack();
    else window.close();
  }
  app.addEventListener('click', event => { const target = event.target.closest('[data-action]'); if (target) handleAction(target.dataset.action, target.dataset.value); });
  dialogRoot.addEventListener('click', event => { const target = event.target.closest('[data-action]'); if (target) handleAction(target.dataset.action, target.dataset.value); });
  document.addEventListener('submit', event => {
    event.preventDefault();
    if (event.target.id === 'search-form') search(event.target.elements.query.value);
    if (event.target.id === 'token-form') { data.token = event.target.elements.token.value.trim(); persist(); notice('TMDB token saved on this TV.'); loadHome(true); }
    if (event.target.id === 'modal-form' && typeof state.modal === 'function') state.modal(event.target);
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' || event.keyCode === 461 || event.key === 'Backspace' && !['INPUT','TEXTAREA'].includes(document.activeElement.tagName)) { event.preventDefault(); back(); return; }
    if ((event.key === 'Enter' || event.keyCode === 13) && document.activeElement && document.activeElement.tagName === 'BUTTON') { event.preventDefault(); document.activeElement.click(); return; }
    const arrow = ['ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(event.key) ? event.key : ({37:'ArrowLeft',38:'ArrowUp',39:'ArrowRight',40:'ArrowDown'})[event.keyCode];
    if (!arrow || ['INPUT','TEXTAREA','SELECT'].includes(document.activeElement.tagName)) return;
    const root = state.modal ? dialogRoot : app;
    const buttons = Array.from(root.querySelectorAll('button, input, select')).filter(el => el.getBoundingClientRect().width > 0);
    const current = document.activeElement;
    if (!buttons.includes(current)) return;
    const rect = current.getBoundingClientRect(); const cx = rect.left + rect.width / 2; const cy = rect.top + rect.height / 2;
    const direction = arrow.replace('Arrow','');
    const choices = buttons.filter(el => el !== current).map(el => {
      const r = el.getBoundingClientRect(); const x = r.left + r.width / 2 - cx; const y = r.top + r.height / 2 - cy;
      const along = direction === 'Right' ? x : direction === 'Left' ? -x : direction === 'Down' ? y : -y;
      const across = direction === 'Left' || direction === 'Right' ? Math.abs(y) : Math.abs(x);
      return { el, along, score: along + across * 1.8 };
    }).filter(x => x.along > 4).sort((a,b) => a.score - b.score);
    if (choices.length) { event.preventDefault(); choices[0].el.focus(); choices[0].el.scrollIntoView({ block: 'nearest', inline: 'nearest' }); }
  });
  window.addEventListener('popstate', back);
  render(); loadHome();
}());
