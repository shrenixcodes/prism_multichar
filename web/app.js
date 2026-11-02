(function () {
    'use strict';

    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'prism_multichar';
    const isDev = typeof window.invokeNative !== 'function';

    const HOLD_DURATION = 1200;

    const app = document.getElementById('app');
    const slotList = document.getElementById('slotList');
    const detailsView = document.getElementById('detailsView');
    const createForm = document.getElementById('createForm');
    const createTitle = document.getElementById('createTitle');
    const spawnPicker = document.getElementById('spawnPicker');
    const spawnList = document.getElementById('spawnList');
    const toast = document.getElementById('toast');

    let locale = {};
    let slots = [];
    let total = 0;
    let currentSlot = 1;
    let inSpawnPicker = false;
    let holdTimer = null;

    function t(key, vars) {
        let text = locale[key] || key;
        if (vars) {
            Object.keys(vars).forEach((name) => {
                text = text.replace('{' + name + '}', vars[name]);
            });
        }
        return text;
    }

    function applyStaticLocale() {
        document.querySelectorAll('[data-locale]').forEach((node) => {
            const key = node.getAttribute('data-locale');
            if (key) {
                node.textContent = t(key);
            }
        });
    }

    function showToast(code) {
        toast.textContent = t('err_' + code, t('err_unknown'));
        toast.classList.remove('hidden');
        window.clearTimeout(toast._timer);
        toast._timer = window.setTimeout(() => toast.classList.add('hidden'), 3500);
    }

    async function fetchNui(name, data) {
        if (isDev) {
            return mockNui(name, data || {});
        }

        const response = await fetch(`https://${resourceName}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        });

        return response.json();
    }

    function formatDate(value) {
        if (!value) {
            return t('value_unknown');
        }
        return String(value).slice(0, 10);
    }

    function formatMoney(value) {
        return '$' + Number(value || 0).toLocaleString('en-US');
    }

    function renderSlots() {
        slotList.innerHTML = '';

        for (let i = 1; i <= total; i += 1) {
            const character = slots[i - 1];
            const li = document.createElement('li');
            li.className = 'slot' + (character ? ' filled' : '') + (i === currentSlot ? ' active' : '');
            li.dataset.slot = String(i);

            const number = document.createElement('span');
            number.className = 'slot-number';
            number.textContent = String(i);

            const info = document.createElement('span');
            info.className = 'slot-info';

            const name = document.createElement('span');
            name.className = 'slot-name';
            name.textContent = character ? `${character.firstname} ${character.lastname}` : t('label_empty_slot');

            const meta = document.createElement('span');
            meta.className = 'slot-meta';
            meta.textContent = character ? t('label_job') + ': ' + character.job : t('label_empty_hint');

            info.appendChild(name);
            info.appendChild(meta);
            li.appendChild(number);
            li.appendChild(info);

            li.addEventListener('click', () => selectSlot(i));
            slotList.appendChild(li);
        }
    }

    function renderDetails(character) {
        detailsView.innerHTML = '';
        createForm.classList.add('hidden');

        if (!character) {
            createForm.classList.remove('hidden');
            createTitle.textContent = t('create_title', { slot: currentSlot });
            createForm.dataset.slot = String(currentSlot);
            return;
        }

        const name = document.createElement('h2');
        name.className = 'details-name';
        name.textContent = `${character.firstname} ${character.lastname}`;
        detailsView.appendChild(name);

        const rows = document.createElement('div');
        rows.className = 'detail-rows';

        const entries = [
            ['label_dob', formatDate(character.dob)],
            ['label_gender', t('gender_' + character.gender)],
            ['label_nationality', character.nationality || t('value_unknown')],
            ['label_job', character.job || t('value_unknown')],
            ['label_cash', formatMoney(character.cash)],
            ['label_bank', formatMoney(character.bank)],
            ['label_last_played', formatDate(character.lastPlayed)]
        ];

        entries.forEach(([labelKey, value]) => {
            const row = document.createElement('div');
            row.className = 'detail-row';

            const label = document.createElement('span');
            label.className = 'label';
            label.textContent = t(labelKey);

            const val = document.createElement('span');
            val.className = 'value';
            val.textContent = value;

            row.appendChild(label);
            row.appendChild(val);
            rows.appendChild(row);
        });

        detailsView.appendChild(rows);

        const actions = document.createElement('div');
        actions.className = 'actions';

        const playBtn = document.createElement('button');
        playBtn.className = 'btn btn-primary';
        playBtn.textContent = t('action_play');
        playBtn.addEventListener('click', () => {
            fetchNui('play', { slot: currentSlot });
        });

        const deleteBtn = document.createElement('button');
        deleteBtn.className = 'btn btn-delete';
        const fill = document.createElement('span');
        fill.className = 'fill';
        const label = document.createElement('span');
        label.textContent = t('action_delete');
        deleteBtn.appendChild(fill);
        deleteBtn.appendChild(label);

        attachHoldToDelete(deleteBtn);

        actions.appendChild(playBtn);
        actions.appendChild(deleteBtn);
        detailsView.appendChild(actions);
    }

    function attachHoldToDelete(button) {
        const start = () => {
            button.classList.add('holding');
            holdTimer = window.setTimeout(() => {
                button.classList.remove('holding');
                fetchNui('deleteCharacter', { slot: currentSlot });
            }, HOLD_DURATION);
        };

        const cancel = () => {
            window.clearTimeout(holdTimer);
            button.classList.remove('holding');
        };

        button.addEventListener('mousedown', start);
        button.addEventListener('mouseup', cancel);
        button.addEventListener('mouseleave', cancel);
    }

    function selectSlot(slot) {
        if (slot < 1 || slot > total || slot === currentSlot) {
            return;
        }

        currentSlot = slot;
        renderSlots();
        renderDetails(slots[slot - 1] || null);
        fetchNui('selectSlot', { slot: currentSlot });
    }

    function renderSpawnPicker(data) {
        inSpawnPicker = true;
        spawnPicker.classList.remove('hidden');
        spawnList.innerHTML = '';

        if (data.hasLastLocation) {
            const li = document.createElement('li');
            li.className = 'spawn-item';
            li.textContent = t('spawn_last_location');
            li.addEventListener('click', () => fetchNui('confirmSpawn', { type: 'last' }));
            spawnList.appendChild(li);
        }

        data.spawns.forEach((spawn, index) => {
            const li = document.createElement('li');
            li.className = 'spawn-item';
            li.textContent = t('spawn_point_' + spawn.label, spawn.label);
            li.addEventListener('click', () => fetchNui('confirmSpawn', { type: 'spawn', index: index + 1 }));
            spawnList.appendChild(li);
        });
    }

    function closeSpawnPicker() {
        inSpawnPicker = false;
        spawnPicker.classList.add('hidden');
    }

    createForm.addEventListener('submit', (event) => {
        event.preventDefault();

        const formData = new FormData(createForm);
        fetchNui('createCharacter', {
            slot: Number(createForm.dataset.slot),
            data: {
                firstname: formData.get('firstname'),
                lastname: formData.get('lastname'),
                dob: formData.get('dob'),
                gender: formData.get('gender'),
                nationality: formData.get('nationality')
            }
        });
    });

    let dragging = false;
    let lastX = 0;

    document.getElementById('stage').addEventListener('mousedown', (event) => {
        dragging = true;
        lastX = event.clientX;
    });

    window.addEventListener('mouseup', () => {
        dragging = false;
    });

    window.addEventListener('mousemove', (event) => {
        if (!dragging) {
            return;
        }
        const delta = event.clientX - lastX;
        lastX = event.clientX;
        fetchNui('rotate', { delta: delta * -0.5 });
    });

    window.addEventListener('keydown', (event) => {
        if (inSpawnPicker) {
            if (event.key === 'Escape') {
                fetchNui('backToScene');
            }
            return;
        }

        if (event.key === 'ArrowUp') {
            selectSlot(Math.max(1, currentSlot - 1));
        } else if (event.key === 'ArrowDown') {
            selectSlot(Math.min(total, currentSlot + 1));
        } else if (event.key === 'Enter') {
            const character = slots[currentSlot - 1];
            if (character) {
                fetchNui('play', { slot: currentSlot });
            }
        }
    });

    window.addEventListener('message', (event) => {
        const message = event.data;

        switch (message.action) {
            case 'open':
                app.classList.remove('hidden');
                window.setTimeout(() => app.classList.add('visible'), 10);
                break;
            case 'slots':
                slots = message.slots;
                total = message.total;
                currentSlot = 1;
                renderSlots();
                renderDetails(slots[0] || null);
                break;
            case 'deleted':
                slots[message.slot - 1] = false;
                renderSlots();
                renderDetails(null);
                break;
            case 'spawnPicker':
                renderSpawnPicker(message);
                break;
            case 'closeSpawnPicker':
                closeSpawnPicker();
                break;
            case 'error':
                showToast(message.code);
                break;
            case 'close':
                app.classList.remove('visible');
                window.setTimeout(() => app.classList.add('hidden'), 400);
                break;
            default:
                break;
        }
    });

    function mockCharacters() {
        return [
            {
                id: 'MOCK01', slot: 1, firstname: 'Ada', lastname: 'Marlowe', dob: '1994-03-11',
                gender: 'female', nationality: 'British', job: 'Mechanic', cash: 1250, bank: 48200,
                lastPlayed: '2026-10-28'
            },
            false,
            {
                id: 'MOCK03', slot: 3, firstname: 'Theo', lastname: 'Granger', dob: '1988-07-22',
                gender: 'male', nationality: 'American', job: 'Unemployed', cash: 80, bank: 1200,
                lastPlayed: '2026-09-02'
            }
        ];
    }

    async function mockNui(name, data) {
        if (name === 'createCharacter') {
            return { success: true, id: 'MOCK_NEW', slot: data.slot };
        }
        if (name === 'deleteCharacter') {
            return { success: true };
        }
        return {};
    }

    async function loadLocale() {
        try {
            const response = await fetch('../locales/en.json');
            locale = await response.json();
        } catch (err) {
            locale = {};
        }
        applyStaticLocale();
    }

    async function init() {
        await loadLocale();

        if (isDev) {
            app.classList.remove('hidden');
            window.setTimeout(() => app.classList.add('visible'), 10);
            slots = mockCharacters();
            total = slots.length;
            renderSlots();
            renderDetails(slots[0]);
        }
    }

    init();
}());
