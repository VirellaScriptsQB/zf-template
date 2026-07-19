const hud = document.getElementById('jobHud');
const minigame = document.getElementById('minigame');
const board = document.getElementById('board');
const leftNodes = document.getElementById('leftNodes');
const rightNodes = document.getElementById('rightNodes');
const wireLayer = document.getElementById('wireLayer');
const tempWire = document.getElementById('tempWire');
const timerEl = document.getElementById('timer');
const faultEl = document.getElementById('faultLabel');
const voltageEl = document.getElementById('voltageReadout');
const continuityEl = document.getElementById('continuity');
const mistakesEl = document.getElementById('mistakes');
const abortButton = document.getElementById('abortButton');

const palette = [
    { key: 'L1', color: '#ff5f65', label: 'L1 RED' },
    { key: 'L2', color: '#4b8dff', label: 'L2 BLUE' },
    { key: 'N', color: '#eceff2', label: 'NEUTRAL' },
    { key: 'G', color: '#59e38e', label: 'GROUND' },
    { key: 'C1', color: '#ffbf3c', label: 'CTRL A' },
    { key: 'C2', color: '#b878ff', label: 'CTRL B' }
];

let state = null;
let drag = null;
let animationFrame = null;

const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'civix-gridservice';

function post(callback, data = {}) {
    return fetch(`https://${resourceName}/${callback}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => null);
}

function shuffle(items) {
    const copy = [...items];
    for (let index = copy.length - 1; index > 0; index -= 1) {
        const target = Math.floor(Math.random() * (index + 1));
        [copy[index], copy[target]] = [copy[target], copy[index]];
    }
    return copy;
}

function endpoint(element) {
    const boardRect = board.getBoundingClientRect();
    const rect = element.getBoundingClientRect();
    return {
        x: rect.left - boardRect.left + rect.width / 2,
        y: rect.top - boardRect.top + rect.height / 2
    };
}

function bezierPath(start, end) {
    const bend = Math.max(70, Math.abs(end.x - start.x) * 0.42);
    return `M ${start.x} ${start.y} C ${start.x + bend} ${start.y}, ${end.x - bend} ${end.y}, ${end.x} ${end.y}`;
}

function drawPermanentWire(leftTerminal, rightTerminal, color) {
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.classList.add('wire');
    path.setAttribute('stroke', color);
    path.setAttribute('d', bezierPath(endpoint(leftTerminal), endpoint(rightTerminal)));
    wireLayer.insertBefore(path, tempWire);
}

function clearPermanentWires() {
    wireLayer.querySelectorAll('.wire').forEach((wire) => wire.remove());
}

function createNode(item, side) {
    const node = document.createElement('div');
    node.className = `node ${side}`;
    node.dataset.key = item.key;
    node.style.setProperty('--wire-color', item.color);

    const label = document.createElement('span');
    label.className = 'node-label';
    label.textContent = item.label;

    const terminal = document.createElement('span');
    terminal.className = 'terminal';
    terminal.dataset.key = item.key;
    terminal.dataset.side = side;

    node.append(label, terminal);
    return node;
}

function setTemporaryWire(start, end) {
    tempWire.setAttribute('x1', start.x);
    tempWire.setAttribute('y1', start.y);
    tempWire.setAttribute('x2', end.x);
    tempWire.setAttribute('y2', end.y);
    tempWire.classList.remove('hidden');
}

function stopDrag() {
    drag = null;
    tempWire.classList.add('hidden');
}

function flashError() {
    board.classList.remove('error');
    void board.offsetWidth;
    board.classList.add('error');
}

function updateContinuity() {
    if (!state) return;
    const connected = state.connected.size;
    const total = state.pairs.length;
    continuityEl.textContent = connected === total ? 'CLOSED' : `${connected}/${total} CLOSED`;
    continuityEl.style.color = connected === total ? '#5cf3a0' : '#f4f7fa';
}

function closeMinigame() {
    cancelAnimationFrame(animationFrame);
    stopDrag();
    minigame.classList.add('hidden');
    minigame.setAttribute('aria-hidden', 'true');
    clearPermanentWires();
    state = null;
}

function finish(success) {
    if (!state || state.finished) return;
    state.finished = true;
    cancelAnimationFrame(animationFrame);

    const elapsed = Math.max(0, (performance.now() - state.startedAt) / 1000);
    const score = Math.max(0, Math.min(100, Math.round(100 - state.mistakes * 11 - elapsed * 0.28)));

    post('wiringResult', {
        token: state.token,
        success,
        mistakes: state.mistakes,
        elapsed,
        score
    });

    closeMinigame();
}

function pointerDown(event) {
    if (!state || state.finished) return;
    const terminal = event.target.closest('.terminal');
    if (!terminal || terminal.dataset.side !== 'left') return;

    const node = terminal.closest('.node');
    if (node.classList.contains('connected')) return;

    event.preventDefault();
    drag = {
        terminal,
        key: terminal.dataset.key,
        start: endpoint(terminal)
    };
    setTemporaryWire(drag.start, drag.start);
}

function pointerMove(event) {
    if (!drag) return;
    const rect = board.getBoundingClientRect();
    setTemporaryWire(drag.start, {
        x: event.clientX - rect.left,
        y: event.clientY - rect.top
    });
}

function pointerUp(event) {
    if (!drag || !state || state.finished) {
        stopDrag();
        return;
    }

    const target = document.elementFromPoint(event.clientX, event.clientY)?.closest('.terminal');
    if (!target || target.dataset.side !== 'right') {
        stopDrag();
        return;
    }

    const rightNode = target.closest('.node');
    if (rightNode.classList.contains('connected')) {
        stopDrag();
        return;
    }

    if (target.dataset.key === drag.key) {
        const leftNode = drag.terminal.closest('.node');
        leftNode.classList.add('connected');
        rightNode.classList.add('connected');
        state.connected.add(drag.key);

        const color = getComputedStyle(leftNode).getPropertyValue('--wire-color').trim();
        drawPermanentWire(drag.terminal, target, color);
        updateContinuity();

        if (state.connected.size === state.pairs.length) {
            setTimeout(() => finish(true), 450);
        }
    } else {
        state.mistakes += 1;
        mistakesEl.textContent = state.mistakes;
        flashError();
    }

    stopDrag();
}

function tick() {
    if (!state || state.finished) return;

    const elapsed = (performance.now() - state.startedAt) / 1000;
    const remaining = Math.max(0, state.timeLimit - elapsed);
    const minutes = Math.floor(remaining / 60).toString().padStart(2, '0');
    const seconds = Math.floor(remaining % 60).toString().padStart(2, '0');

    timerEl.textContent = `${minutes}:${seconds}`;
    timerEl.classList.toggle('danger', remaining <= 15);

    if (remaining <= 0) {
        finish(false);
        return;
    }

    animationFrame = requestAnimationFrame(tick);
}

function openMinigame(data) {
    const pairCount = Math.max(3, Math.min(6, Number(data.difficulty) || 4));
    const selected = shuffle(palette).slice(0, pairCount);

    state = {
        token: data.token,
        pairs: selected,
        connected: new Set(),
        mistakes: 0,
        startedAt: performance.now(),
        timeLimit: Math.max(20, Number(data.timeLimit) || 90),
        finished: false
    };

    leftNodes.innerHTML = '';
    rightNodes.innerHTML = '';
    clearPermanentWires();

    selected.forEach((item) => leftNodes.appendChild(createNode(item, 'left')));
    shuffle(selected).forEach((item) => rightNodes.appendChild(createNode(item, 'right')));

    faultEl.textContent = data.fault || 'Unknown fault';
    voltageEl.textContent = data.expectedVoltage || '-- V';
    continuityEl.textContent = `0/${pairCount} CLOSED`;
    continuityEl.style.color = '#f4f7fa';
    mistakesEl.textContent = '0';
    timerEl.classList.remove('danger');

    minigame.classList.remove('hidden');
    minigame.setAttribute('aria-hidden', 'false');

    requestAnimationFrame(() => {
        if (!state) return;
        state.startedAt = performance.now();
        tick();
    });
}

function updateHud(data) {
    const visible = data.visible !== false;
    hud.classList.toggle('hidden', !visible);
    hud.setAttribute('aria-hidden', visible ? 'false' : 'true');
    if (!visible) return;

    document.getElementById('hudProgress').textContent = `${data.stop || 0} / ${data.total || 0}`;
    document.getElementById('hudDistrict').textContent = data.district || 'Awaiting dispatch';
    document.getElementById('hudLabel').textContent = data.label || 'No active work order';
    document.getElementById('hudStatus').textContent = data.status || 'Stand by';
    document.getElementById('hudFault').textContent = data.fault || 'Diagnosis pending';
    document.getElementById('hudDistance').textContent = Number.isFinite(data.distance) ? `${data.distance} m` : '-- m';
    document.getElementById('hudRank').textContent = data.rank || 'Grid Apprentice';
    document.getElementById('hudXp').textContent = `${data.xp || 0} XP`;
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'hud') updateHud(data);
    if (data.action === 'openMinigame') openMinigame(data);
    if (data.action === 'closeMinigame') closeMinigame();
});

window.addEventListener('pointerdown', pointerDown);
window.addEventListener('pointermove', pointerMove);
window.addEventListener('pointerup', pointerUp);
window.addEventListener('pointercancel', stopDrag);

window.addEventListener('resize', () => {
    if (!state) return;
    clearPermanentWires();
    state.connected.clear();
    document.querySelectorAll('.node.connected').forEach((node) => node.classList.remove('connected'));
    updateContinuity();
});

abortButton.addEventListener('click', () => {
    if (!state || state.finished) return;
    state.finished = true;
    cancelAnimationFrame(animationFrame);
    post('close');
    closeMinigame();
});

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && state && !state.finished) {
        state.finished = true;
        cancelAnimationFrame(animationFrame);
        post('close');
        closeMinigame();
    }
});
