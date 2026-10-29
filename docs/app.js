(() => {
  const $ = (sel, root = document) => root.querySelector(sel);
  const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const store = {
    get(key) { try { return localStorage.getItem(key); } catch { return null; } },
    set(key, value) { try { localStorage.setItem(key, value); } catch { /* private mode */ } },
  };

  // =========================================================
  // Language — English lives in the HTML (what search engines
  // index); Turkish is applied on top.
  // =========================================================
  const TR = {
    'nav.free': 'Ücretsiz',
    'nav.features': 'Özellikler',
    'nav.faq': 'SSS',
    'hero.line1': 'Her pencere',
    'hero.line2': 'bir Tab uzağında.',
    'hero.lead': 'Mac’in için ücretsiz ve açık kaynak bir pencere değiştirici. ⌥’ye bas, Tab’a dokun ve her pencereyi gör — diğer masaüstlerindekiler dahil.',
    'hero.download': 'Ücretsiz indir',
    'hero.github': 'GitHub’da yıldızla',
    'mb.file': 'Dosya', 'mb.edit': 'Düzen', 'mb.view': 'Görüntü', 'mb.window': 'Pencere',
    'lock.note': 'İskelede bekleyen beş pencere var.',
    'lock.unlock': 'Kilidi açmak için tıkla',
    'lock.unlockNote': 'şifre yok, söz',
    'sw.empty': 'Eşleşen pencere yok',
    'demo.hint': 'Kilidi aç, sonra <kbd>⌥</kbd>’ye basılı tutup <kbd>Tab</kbd>’a dokun. Klavye yok mu? Düğmeyi kullan. Ferry zaten açık mı? Bu sayfada kenara çekilir.',
    'demo.try': 'Değiştir',
    'features.title': 'Pencere değiştirmenin olması gerektiği hali.',
    'f1.t': 'Uygulama değil, pencere', 'f1.d': 'Üç Safari penceresi tek değil, üç seçenek.',
    'f2.t': 'Her Space', 'f2.d': 'Diğer masaüstleri, küçültülenler, gizlenenler — kaybolmaz, işaretlenir.',
    'f3.t': 'Dock önizlemeleri', 'f3.d': 'Bir simgenin üzerinde dur, o uygulamanın pencerelerini gör.',
    'f4.t': 'Arama', 'f4.d': 'Boşluk’a bas ve yaz. Başlıklar ve uygulama adları.',
    'f5.t': 'Hızlı işlemler', 'f5.d': 'W kapatır, M küçültür, Q çıkar — bırakmadan.',
    'f6.t': 'Gerekene kadar uykuda', 'f6.d': 'Yoklama yok, fare takibi yok. Boştayken neredeyse sıfır CPU.',
    'f7.t': 'Gizli', 'f7.d': 'Görüntüler bellekte durur. Hiçbir şey Mac’inden çıkmaz.',
    'f8.t': 'Birden çok ekran', 'f8.d': 'İmlecin olduğu ekranda ya da etkin pencerenin yanında açılır.',
    'f9.t': 'Varsayılan olarak nazik', 'f9.d': 'Hareketi, saydamlığı azaltma ve kontrast tercihlerine uyar.',
    'f10.t': '⌥, ⌘ ya da ⌃', 'f10.d': '⌘Tab’ı devral ya da onu bırakıp ⌥Tab kullan.',
    'f11.t': 'English ve Türkçe', 'f11.d': 'Mac’ini takip eder ya da Ayarlar’dan seçersin.',
    'f12.t': 'Açık kaynak', 'f12.d': 'MIT lisanslı. Oku, çatalla, geliştir.',
    'numbers.title': 'Unutacak kadar hafif.',
    'numbers.lead': 'M4 Pro’da, on açık pencereyle ölçüldü. Ferry kısayola bastığında ya da Dock’ta durduğunda uyanır, sonra yeniden uyur.',
    'numbers.idle': 'boştayken CPU',
    'numbers.open': 'kısayoldan pencere listesine',
    'numbers.mem': 'bellek, görüntüler dahil',
    'cta.title': 'Ücretsiz. Sessiz. Senin.',
    'cta.lead': 'Hesap yok, takip yok, deneme süresi yok.',
    'cta.note': 'macOS 15 veya üstü. Zip’i aç, Ferry’yi Uygulamalar’a taşı; ilk seferde sağ tıklayıp Aç’ı seç.',
    'faq.title': 'Sorular',
    'q1.q': 'Gerçekten ücretsiz mi?', 'q1.a': 'Evet. Ferry MIT lisanslı, açık kaynak. Deneme yok, Pro sürüm yok, satış yok.',
    'q2.q': 'Neden Erişilebilirlik izni istiyor?', 'q2.a': 'Pencerelerini listelemek, kısayolu fark etmek ve seçtiğin pencereyi öne getirmek için. Bu izin olmadan bir pencere değiştirici pencere değiştiremez.',
    'q3.q': 'Ekranımı kaydediyor mu?', 'q3.a': 'Hayır. Ekran Kaydı isteğe bağlı ve yalnızca switcher ya da bir Dock önizlemesi bir pencereyi göstermek üzereyken onun küçük, tek bir görüntüsünü almak için kullanılır. Görüntüler bellekte durur, pencere kapanınca silinir, asla kaydedilmez ya da bir yere gönderilmez. İzni vermezsen Ferry uygulama simgelerini gösterir.',
    'q4.q': '⌘Tab’ın yerini alabilir mi?', 'q4.a': 'Evet. Ayarlar’da ⌘’yi seç; Ferry çalıştığı sürece ⌘Tab’ı devralır, çıkınca macOS’e geri verir.',
    'q5.q': 'AltTab ya da DockDoor ile birlikte kullanabilir miyim?', 'q5.a': 'Aynı anda olmasa iyi: hepsi aynı kısayolu ve aynı Dock hareketini dinliyor. Birini seç.',
    'q6.q': 'macOS açılamıyor diyor.', 'q6.a': 'Sürümler henüz notarize edilmedi. Ferry’ye sağ tıklayıp Aç’ı seç ya da şunu çalıştır: <code>xattr -dr com.apple.quarantine /Applications/Ferry.app</code>',
    'q7.q': 'Duvar kağıdındaki küçük vapur bir işe yarıyor mu?', 'q7.a': 'Her pencere değiştirdiğinde biraz ilerliyor. Bu kadar. Özellik bu.',
    'footer.license': 'MIT Lisansı',
    'footer.releases': 'Sürümler',
    'footer.inlet': 'Ayrıca: Inlet',
    'footer.inspiration': '<a href="https://alt-tab.app">AltTab</a> ve <a href="https://dockdoor.net">DockDoor</a>’dan ilham aldı. Ferry ayrı bir projedir ve onlarla hiç kod paylaşmaz.',
    'footer.disclaimer': 'Ferry bağımsız bir projedir; Apple Inc. ile bağlantılı değildir, Apple tarafından onaylanmamış veya desteklenmemiştir. Mac, macOS ve Mission Control, Apple Inc.’in ABD’de ve diğer ülkelerde tescilli ticari markalarıdır.',
  };

  // Strings the demo builds at runtime.
  const DYN = {
    en: {
      hints: [['⇥', 'Next'], ['space', 'Search'], ['W', 'Close'], ['M', 'Minimize'], ['Q', 'Quit'], ['esc', 'Cancel']],
      searchHints: [['↩', 'Open'], ['⇥', 'Next'], ['esc', 'Cancel']],
      placeholder: 'Type to search windows',
      closed: (t) => `“${t}” closed. It’ll be back in a moment — this is a demo.`,
      quit: (a) => `${a} quit. It’ll be back; they always are.`,
      crossing: (n) => `Crossing to Desktop ${n}…`,
      windows: (n) => (n === 1 ? '1 window' : `${n} windows`),
      visit: 'Visit site ↗',
    },
    tr: {
      hints: [['⇥', 'Sonraki'], ['boşluk', 'Ara'], ['W', 'Kapat'], ['M', 'Küçült'], ['Q', 'Çık'], ['esc', 'Vazgeç']],
      searchHints: [['↩', 'Aç'], ['⇥', 'Sonraki'], ['esc', 'Vazgeç']],
      placeholder: 'Pencere aramak için yaz',
      closed: (t) => `“${t}” kapandı. Birazdan geri gelir; burası bir demo.`,
      quit: (a) => `${a} kapandı. Geri gelecek; hep gelirler.`,
      crossing: (n) => `Masaüstü ${n}’ye geçiliyor…`,
      windows: (n) => `${n} pencere`,
      visit: 'Siteye git ↗',
    },
  };

  const nodes = $$('[data-i18n]');
  const EN = Object.fromEntries(nodes.map((n) => [n.dataset.i18n, n.innerHTML]));
  const langButton = $('#lang');
  let lang = 'en';
  const t = (key) => DYN[lang][key];
  const locale = () => (lang === 'tr' ? 'tr-TR' : 'en-US');

  function setLanguage(next) {
    lang = next;
    const dict = next === 'tr' ? TR : EN;
    nodes.forEach((n) => { n.innerHTML = dict[n.dataset.i18n] ?? EN[n.dataset.i18n]; });
    document.documentElement.lang = next;
    langButton.textContent = next === 'tr' ? 'EN' : 'TR';
    langButton.setAttribute('aria-label', next === 'tr' ? 'Switch to English' : 'Türkçeye geç');
    store.set('lang', next);
    tickClock();
    renderWindows();
    if (sw.open) buildSwitcher();
  }

  // =========================================================
  // Layout: the Mac is built at 960×600 and scaled to fit.
  // =========================================================
  const frame = $('#macFrame');
  const mac = $('#mac');
  let k = 1;
  function fit() {
    const pad = parseFloat(getComputedStyle(frame).paddingLeft);
    k = (frame.clientWidth - pad * 2) / 960;
    mac.style.transform = `scale(${k})`;
    frame.style.height = `${600 * k + pad * 2}px`;
  }
  addEventListener('resize', fit);
  fit();

  const nav = $('#nav');
  const onScroll = () => nav.classList.toggle('scrolled', scrollY > 8);
  addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  // =========================================================
  // Clocks
  // =========================================================
  function tickClock() {
    const now = new Date();
    const time = now.toLocaleTimeString(locale(), { hour: 'numeric', minute: '2-digit' });
    $('#lockTime').textContent = time.replace(/\s?[AP]M$/i, '');
    $('#lockDate').textContent = now.toLocaleDateString(locale(), { weekday: 'long', day: 'numeric', month: 'long' });
    $('#menuClock').textContent = `${now.toLocaleDateString(locale(), { weekday: 'short' })} ${time}`;
  }
  setInterval(tickClock, 10_000);

  // =========================================================
  // Spring (response + damping ratio). Always animates from the
  // current value and keeps velocity when re-targeted.
  // =========================================================
  class Spring {
    constructor(value) { this.value = value; this.target = value; this.velocity = 0; }
    step(dt, response, damping) {
      const stiffness = (2 * Math.PI / response) ** 2;
      const friction = (4 * Math.PI * damping) / response;
      this.velocity += (-stiffness * (this.value - this.target) - friction * this.velocity) * dt;
      this.value += this.velocity * dt;
    }
    settledWithin(epsilon) { return Math.abs(this.value - this.target) < epsilon && Math.abs(this.velocity) < epsilon; }
    snap() { this.value = this.target; this.velocity = 0; }
  }

  // Runs a group of springs until they rest, then calls `done`. Starting a
  // group again re-targets it from wherever it is now.
  function animate(springs, apply, params = { response: 0.3, damping: 1 }, done) {
    let last = 0;
    if (springs._raf) cancelAnimationFrame(springs._raf);
    const epsilon = params.epsilon ?? 0.05;
    if (reduceMotion.matches) {
      springs.forEach((s) => s.snap());
      apply();
      springs._raf = 0;
      done?.();
      return;
    }
    const frameFn = (time) => {
      const dt = Math.min(0.05, (time - (last || time)) / 1000);
      last = time;
      const steps = Math.max(1, Math.ceil(dt / (1 / 240)));
      for (let i = 0; i < steps; i++) springs.forEach((s) => s.step(dt / steps, params.response, params.damping));
      if (springs.every((s) => s.settledWithin(epsilon))) {
        springs.forEach((s) => s.snap());
        apply();
        springs._raf = 0;
        done?.();
        return;
      }
      apply();
      springs._raf = requestAnimationFrame(frameFn);
    };
    springs._raf = requestAnimationFrame(frameFn);
  }

  // =========================================================
  // Apps and windows
  // =========================================================
  const APPS = {
    driftwood: { name: 'Driftwood', color: '#e8a33d', letter: 'D' },
    compass: { name: 'Compass', color: '#3d7be8', letter: 'C' },
    keel: { name: 'Keel', color: '#2f2a26', letter: 'K' },
    gull: { name: 'Gull Mail', color: '#3fa58a', letter: 'G' },
    lantern: { name: 'Lantern', color: '#d9546e', letter: 'L' },
    ferry: { name: 'Ferry', icon: 'assets/icon.png?v=1' },
  };

  const PHOTO = ['#e8a07a', '#7ab0d6', '#d9c27a', '#a7c98f', '#d68ba0', '#9f8fd1', '#e0b48c', '#86c2b8'];

  const WINDOWS = [
    {
      id: 'compass', app: 'compass', x: 290, y: 96, w: 520, h: 330, space: 1,
      title: { en: 'Harbor — free Mac apps', tr: 'Harbor — ücretsiz Mac uygulamaları' },
      body: (l) => `<div class="browser"><div class="url">kaandis.github.io/harbor</div>
        <div class="page"><h4>Harbor</h4><p>${l === 'tr' ? 'Ücretsiz Mac uygulamaları, tek bir limanda.' : 'Free Mac apps, one shared harbor.'}</p></div>
        <div class="cards"><div>Inlet</div><div>Ferry</div><div>${l === 'tr' ? 'Sıradaki gemi…' : 'Next ship…'}</div></div></div>`,
    },
    {
      id: 'driftwood', app: 'driftwood', x: 60, y: 62, w: 400, h: 290, space: 1,
      title: { en: 'Things to switch to', tr: 'Geçilecek şeyler' },
      body: (l) => (l === 'tr'
        ? `<div class="notes"><aside><p>Market</p><p class="on">Geçilecek şeyler</p><p>Fikirler (2)</p></aside>
           <article><h4>Geçilecek şeyler</h4><ol><li>Az önce olduğun pencere</li><li>Ondan önceki</li><li>Ondan da önceki</li><li><s>Verimlilik</s></li></ol></article></div>`
        : `<div class="notes"><aside><p>Groceries</p><p class="on">Things to switch to</p><p>Ideas (2)</p></aside>
           <article><h4>Things to switch to</h4><ol><li>The window you were just in</li><li>The one before that</li><li>The one before <em>that</em></li><li><s>Productivity</s></li></ol></article></div>`),
    },
    {
      id: 'keel', app: 'keel', x: 540, y: 48, w: 370, h: 250, space: 1,
      title: { en: 'ferry — Switcher.swift', tr: 'ferry — Switcher.swift' },
      body: (l) => `<div class="code"><span class="c">// Switcher.swift</span>
<span class="k">while</span> holdingOption {
    <span class="f">tab</span>()
}
<span class="f">letGo</span>()  <span class="c">// and you're there</span>

<span class="c">// TODO: ${l === 'tr' ? 'biraz çimlere dokun' : 'touch grass'}</span></div>`,
    },
    {
      id: 'gull', app: 'gull', x: 140, y: 232, w: 460, h: 270, space: 1,
      title: { en: 'Inbox — 3 new', tr: 'Gelen Kutusu — 3 yeni' },
      body: (l) => (l === 'tr'
        ? `<div class="mail"><ul><li class="on"><b>Ynt: Ynt: Ynt: kısa bir soru</b>Şu diğer şeyle ilgili…</li><li><b>Pencerelerin seni özledi</b>Ferry</li><li><b>Öğle yemeği?</b>12:30 olur mu</li></ul>
           <article><h4>Ynt: Ynt: Ynt: kısa bir soru</h4>Şu diğer şeyle ilgili olan şeye dönüyorum. Acele yok! (Biraz var.)</article></div>`
        : `<div class="mail"><ul><li class="on"><b>Re: Re: Re: quick question</b>Just circling back on…</li><li><b>Your windows miss you</b>Ferry</li><li><b>Lunch?</b>12:30 work?</li></ul>
           <article><h4>Re: Re: Re: quick question</h4>Just circling back on the thing about the other thing. No rush! (Some rush.)</article></div>`),
    },
    {
      id: 'lantern', app: 'lantern', x: 330, y: 120, w: 340, h: 250, space: 2,
      title: { en: 'Coastline, October', tr: 'Sahil, Ekim' },
      body: () => `<div class="photos">${Array.from({ length: 12 }, (_, i) => `<i style="background:${PHOTO[i % PHOTO.length]}"></i>`).join('')}</div>`,
    },
    {
      id: 'welcome', app: 'ferry', x: 340, y: 70, w: 300, h: 300, space: 1, state: 'closed',
      title: { en: 'Welcome to Ferry', tr: 'Ferry’ye hoş geldin' },
      body: (l) => `<div style="padding:18px;text-align:center"><img src="assets/icon.png?v=1" width="54" height="54" style="margin:0 auto" alt="">
        <h4 style="margin:10px 0 4px;font-size:17px;letter-spacing:-.02em">${l === 'tr' ? 'Ferry’ye hoş geldin' : 'Welcome to Ferry'}</h4>
        <p style="margin:0 0 12px;font-size:12px;color:#6e625a">${l === 'tr' ? 'Her pencere bir Tab uzağında.' : 'Every window, one Tab away.'}</p>
        ${[[l === 'tr' ? 'Erişilebilirlik' : 'Accessibility'], [l === 'tr' ? 'Ekran Kaydı' : 'Screen Recording']].map(([n]) => `<div style="display:flex;justify-content:space-between;align-items:center;margin-top:6px;padding:9px 12px;border-radius:12px;background:#fffbf6;box-shadow:inset 0 0 0 1px rgba(35,31,28,.08);font-size:12.5px;font-weight:600">${n}<span style="color:#c4503b">✓</span></div>`).join('')}</div>`,
    },
    {
      id: 'settings', app: 'ferry', x: 380, y: 110, w: 320, h: 240, space: 1, state: 'closed',
      title: { en: 'Ferry Settings', tr: 'Ferry Ayarları' },
      body: (l) => `<div style="padding:14px 16px;font-size:12.5px">${(l === 'tr'
        ? [['Kısayol', '⌥ Option + Tab'], ['Göründüğü yer', 'İmlecin ekranı'], ['Kaynak', 'Tüm Space’ler'], ['Dock önizlemeleri', 'Açık']]
        : [['Shortcut', '⌥ Option + Tab'], ['Show on', 'Pointer’s display'], ['Windows from', 'All Spaces'], ['Dock previews', 'On']])
        .map(([a, b]) => `<div style="display:flex;justify-content:space-between;padding:9px 2px;border-bottom:1px solid rgba(35,31,28,.08)"><b style="font-weight:550">${a}</b><span style="color:#6e625a">${b}</span></div>`).join('')}</div>`,
    },
  ];
  WINDOWS.forEach((w) => {
    w.state = w.state || 'open';
    w.anim = [new Spring(1), new Spring(0), new Spring(0), new Spring(1)]; // scale, dx, dy, opacity
  });
  const byId = Object.fromEntries(WINDOWS.map((w) => [w.id, w]));

  // Most recently used first; this is the switcher's order.
  let order = ['compass', 'driftwood', 'keel', 'gull', 'lantern', 'welcome', 'settings'];
  let currentSpace = 1;
  const windowsLayer = $('#windows');

  function appBadge(appId, size = 14) {
    const app = APPS[appId];
    if (app.icon) return `<img src="${app.icon}" width="${size}" height="${size}" alt="">`;
    return `<i class="app-dot" style="background:${app.color};width:${size}px;height:${size}px">${app.letter}</i>`;
  }

  function renderWindows() {
    WINDOWS.forEach((w) => {
      if (!w.el) {
        w.el = document.createElement('div');
        w.el.className = 'win';
        w.el.dataset.id = w.id;
        w.el.innerHTML = '<div class="win-bar"><span class="lights"><i></i><i></i><i></i></span><span class="win-title"></span></div><div class="win-body"></div>';
        windowsLayer.append(w.el);
        attachWindowHandlers(w);
      }
      w.el.style.left = `${w.x}px`;
      w.el.style.top = `${w.y}px`;
      w.el.style.width = `${w.w}px`;
      w.el.style.height = `${w.h}px`;
      $('.win-title', w.el).textContent = w.title[lang];
      $('.win-body', w.el).innerHTML = w.body(lang);
    });
    applyStacking();
  }

  function applyStacking() {
    const front = order.find((id) => isVisible(byId[id]) && byId[id].state === 'open');
    WINDOWS.forEach((w) => {
      w.el.style.zIndex = String(100 - order.indexOf(w.id));
      w.el.classList.toggle('front', w.id === front);
      w.el.style.display = isVisible(w) ? '' : 'none';
    });
    $('#activeApp').textContent = front ? APPS[byId[front].app].name : 'Finder';
  }

  const isVisible = (w) => w.space === currentSpace && w.state !== 'closed';

  function applyWindowAnim(w) {
    const [s, dx, dy, o] = w.anim;
    w.el.style.transform = `translate(${dx.value}px, ${dy.value}px) scale(${s.value})`;
    w.el.style.opacity = String(Math.max(0, Math.min(1, o.value)));
    w.el.style.pointerEvents = w.state === 'open' ? '' : 'none';
  }

  // The ferry on the wallpaper moves along every time you switch.
  const boat = $('#ferryBoat');
  const boatX = [new Spring(120)];
  function sailBoat() {
    let next = boatX[0].target + 52;
    if (next > 900) {
      boatX[0].value = -90;
      boatX[0].velocity = 0;
      next = 10;
    }
    boatX[0].target = next;
    animate(boatX, () => boat.setAttribute('transform', `translate(${boatX[0].value.toFixed(1)} 382)`), { response: 0.9, damping: 1 });
  }

  function focusWindow(id) {
    const w = byId[id];
    const wasFront = order[0] === id && w.state === 'open' && w.space === currentSpace;
    const finish = () => {
      if (w.state === 'minimized' || w.state === 'closed') restoreWindow(w);
      order = [id, ...order.filter((x) => x !== id)];
      applyStacking();
      if (!wasFront) sailBoat();
    };
    if (w.space !== currentSpace && w.state !== 'closed') switchSpace(w.space, finish);
    else finish();
  }

  function restoreWindow(w) {
    const coming = w.state === 'closed';
    w.state = 'open';
    if (coming) {
      w.space = currentSpace;
      w.anim[0].value = 0.96;
      w.anim[3].value = 0;
    }
    applyStacking();
    w.anim[0].target = 1;
    w.anim[1].target = 0;
    w.anim[2].target = 0;
    w.anim[3].target = 1;
    animate(w.anim, () => applyWindowAnim(w), { response: 0.36, damping: 1, epsilon: 0.002 });
  }

  // Minimized windows travel into the Dock, the way they'll come back.
  function minimizeWindow(w) {
    if (w.state !== 'open') return;
    w.state = 'minimized';
    const dock = $('#dock').getBoundingClientRect();
    const box = w.el.getBoundingClientRect();
    w.anim[0].target = 0.12;
    w.anim[1].target = ((dock.left + dock.width / 2) - (box.left + box.width / 2)) / k;
    w.anim[2].target = (dock.top - box.bottom) / k + 20;
    w.anim[3].target = 0;
    animate(w.anim, () => applyWindowAnim(w), { response: 0.42, damping: 1, epsilon: 0.002 });
    applyStacking();
  }

  function closeWindow(w, message) {
    w.state = 'closed';
    w.anim[0].target = 0.96;
    w.anim[3].target = 0;
    animate(w.anim, () => applyWindowAnim(w), { response: 0.22, damping: 1, epsilon: 0.002 }, applyStacking);
    toast(message);
    // It's a demo: closed windows come back on their own.
    if (w.app !== 'ferry') setTimeout(() => { if (w.state === 'closed') { restoreWindow(w); order = [...order.filter((x) => x !== w.id), w.id]; applyStacking(); } }, 4000);
  }

  // Spaces: the desktop slides away and the other one slides in.
  const spaceAnim = [new Spring(0), new Spring(1)];
  function switchSpace(to, done) {
    const dir = to > currentSpace ? -1 : 1;
    toast(t('crossing')(to));
    const apply = () => {
      windowsLayer.style.transform = `translateX(${spaceAnim[0].value}px)`;
      windowsLayer.style.opacity = String(spaceAnim[1].value);
    };
    spaceAnim[0].target = dir * 90;
    spaceAnim[1].target = 0;
    animate(spaceAnim, apply, { response: 0.22, damping: 1, epsilon: 0.01 }, () => {
      currentSpace = to;
      done();
      spaceAnim[0].value = -dir * 90;
      spaceAnim[0].target = 0;
      spaceAnim[1].target = 1;
      animate(spaceAnim, apply, { response: 0.3, damping: 1, epsilon: 0.01 });
    });
  }

  // Drag by the title bar, 1:1 from where you grabbed it.
  function attachWindowHandlers(w) {
    const bar = $('.win-bar', w.el);
    w.el.addEventListener('pointerdown', () => { if (order[0] !== w.id) focusWindow(w.id); });
    bar.addEventListener('pointerdown', (e) => {
      if (e.button !== 0) return;
      bar.setPointerCapture(e.pointerId);
      bar.classList.add('dragging');
      const start = { px: e.clientX, py: e.clientY, x: w.x, y: w.y };
      const move = (ev) => {
        w.x = Math.round(Math.min(900, Math.max(-w.w + 80, start.x + (ev.clientX - start.px) / k)));
        w.y = Math.round(Math.min(520, Math.max(28, start.y + (ev.clientY - start.py) / k)));
        w.el.style.left = `${w.x}px`;
        w.el.style.top = `${w.y}px`;
      };
      const end = () => {
        bar.classList.remove('dragging');
        bar.removeEventListener('pointermove', move);
        bar.removeEventListener('pointerup', end);
        bar.removeEventListener('pointercancel', end);
      };
      bar.addEventListener('pointermove', move);
      bar.addEventListener('pointerup', end);
      bar.addEventListener('pointercancel', end);
    });
  }

  // =========================================================
  // Toast
  // =========================================================
  const toastEl = $('#toast');
  let toastTimer = 0;
  function toast(text) {
    toastEl.textContent = text;
    toastEl.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove('show'), 2400);
  }

  // =========================================================
  // Switcher
  // =========================================================
  const switcher = $('#switcher');
  const panel = $('#swPanel');
  const grid = $('#swGrid');
  const ring = $('#swRing');
  const TILE_W = 168;
  const THUMB = { w: 152, h: 96 };
  const sw = { open: false, shown: false, items: [], sel: 0, searching: false, query: '', showTimer: 0, hoverArmed: false };
  const present = [new Spring(0)];
  const ringPos = [new Spring(0), new Spring(0)];

  function switcherItems() {
    const list = order.map((id) => byId[id]).filter((w) => w.state !== 'closed');
    if (!sw.query) return list;
    const q = sw.query.toLocaleLowerCase(locale());
    return list.filter((w) => w.title[lang].toLocaleLowerCase(locale()).includes(q) || APPS[w.app].name.toLowerCase().includes(q));
  }

  function thumbFor(w) {
    const scale = Math.min(THUMB.w / w.w, THUMB.h / w.h);
    const clone = w.el.cloneNode(true);
    clone.removeAttribute('style');
    clone.style.width = `${w.w}px`;
    clone.style.height = `${w.h}px`;
    clone.style.display = 'block';
    const holder = document.createElement('div');
    holder.className = 'clone';
    holder.style.transform = `scale(${scale})`;
    holder.style.left = `${(THUMB.w - w.w * scale) / 2}px`;
    holder.style.top = `${(THUMB.h - w.h * scale) / 2}px`;
    holder.append(clone);
    return holder;
  }

  function buildSwitcher() {
    sw.items = switcherItems();
    sw.sel = Math.min(sw.sel, Math.max(0, sw.items.length - 1));
    $$('.sw-tile', grid).forEach((n) => n.remove());
    grid.style.setProperty('--cols', String(Math.min(4, Math.max(1, sw.items.length))));
    sw.items.forEach((w, i) => {
      const tile = document.createElement('div');
      tile.className = 'sw-tile';
      tile.setAttribute('role', 'option');
      const thumb = document.createElement('div');
      thumb.className = `sw-thumb${w.state === 'minimized' ? ' minimized' : ''}`;
      thumb.append(thumbFor(w));
      if (w.state === 'minimized') thumb.insertAdjacentHTML('beforeend', '<span class="sw-badge">–</span>');
      else if (w.space !== currentSpace) thumb.insertAdjacentHTML('beforeend', `<span class="sw-badge">⧉ ${w.space}</span>`);
      tile.append(thumb);
      tile.insertAdjacentHTML('beforeend', `<div class="sw-cap">${appBadge(w.app)}<span></span></div>`);
      $('.sw-cap span', tile).textContent = w.title[lang];
      tile.addEventListener('pointermove', () => { if (sw.hoverArmed && sw.sel !== i) select(i); });
      tile.addEventListener('click', () => { sw.sel = i; commit(); });
      grid.append(tile);
    });
    $('#swEmpty').hidden = sw.items.length > 0;
    grid.hidden = sw.items.length === 0;
    const search = $('#swSearch');
    search.hidden = !sw.searching;
    const query = $('#swQuery');
    query.textContent = sw.query;
    query.dataset.placeholder = t('placeholder');
    $('.caret', search).hidden = !sw.query;
    $('#swHints').innerHTML = (sw.searching ? t('searchHints') : t('hints'))
      .map(([key, label]) => `<span><kbd>${key}</kbd>${label}</span>`).join('');
    markSelection(false);
  }

  function markSelection(animated) {
    const tiles = $$('.sw-tile', grid);
    tiles.forEach((tile, i) => tile.classList.toggle('sel', i === sw.sel));
    const tile = tiles[sw.sel];
    ring.style.display = tile ? '' : 'none';
    if (!tile) return;
    ring.style.width = `${tile.offsetWidth}px`;
    ring.style.height = `${tile.offsetHeight}px`;
    ringPos[0].target = tile.offsetLeft;
    ringPos[1].target = tile.offsetTop;
    const apply = () => { ring.style.transform = `translate(${ringPos[0].value}px, ${ringPos[1].value}px)`; };
    if (!animated) {
      ringPos.forEach((s) => s.snap());
      apply();
    } else {
      animate(ringPos, apply, { response: 0.2, damping: 1, epsilon: 0.2 });
    }
  }

  function select(index) {
    if (!sw.items.length) return;
    const n = sw.items.length;
    sw.sel = ((index % n) + n) % n;
    markSelection(true);
  }

  function applyPresent() {
    const p = Math.max(0, Math.min(1, present[0].value));
    panel.style.opacity = String(p);
    panel.style.transform = reduceMotion.matches ? 'none' : `scale(${0.94 + 0.06 * p})`;
  }

  function openSwitcher(step, immediate) {
    if (mac.classList.contains('locked')) return;
    hideDockPreview();
    sw.open = true;
    sw.searching = false;
    sw.query = '';
    sw.hoverArmed = false;
    sw.sel = step;
    buildSwitcher();
    select(step);
    markSelection(false);
    switcher.classList.add('open');
    clearTimeout(sw.showTimer);
    // A quick tap-and-release switches without the panel ever appearing.
    const show = () => {
      sw.shown = true;
      present[0].target = 1;
      animate(present, applyPresent, { response: 0.28, damping: 1, epsilon: 0.002 });
    };
    if (immediate || sw.shown) show(); else sw.showTimer = setTimeout(show, 90);
  }

  function closeSwitcher() {
    clearTimeout(sw.showTimer);
    clearTimeout(tryTimer);
    sw.open = false;
    sw.searching = false;
    switcher.classList.remove('open');
    if (!sw.shown) return;
    present[0].target = 0;
    animate(present, applyPresent, { response: 0.28, damping: 1, epsilon: 0.002 }, () => { if (!sw.open) sw.shown = false; });
  }

  function commit() {
    if (!sw.open) return;
    const w = sw.items[sw.sel];
    closeSwitcher();
    if (w) focusWindow(w.id);
  }

  function act(kind) {
    const w = sw.items[sw.sel];
    if (!w) return;
    if (kind === 'close') closeWindow(w, t('closed')(w.title[lang]));
    if (kind === 'quit') closeWindow(w, t('quit')(APPS[w.app].name));
    if (kind === 'minimize') {
      if (w.state === 'minimized') restoreWindow(w); else minimizeWindow(w);
    }
    buildSwitcher();
  }

  switcher.addEventListener('pointermove', () => { sw.hoverArmed = true; });
  switcher.addEventListener('click', (e) => { if (e.target === switcher) closeSwitcher(); });

  // Keyboard: hold ⌥, tap Tab. Only while the demo is on screen.
  let demoVisible = false;
  new IntersectionObserver(([entry]) => { demoVisible = entry.isIntersecting; }, { threshold: 0.35 }).observe(frame);

  addEventListener('keydown', (e) => {
    if (!demoVisible || mac.classList.contains('locked')) return;
    if (e.altKey && e.code === 'Tab') {
      e.preventDefault();
      if (!sw.open) openSwitcher(e.shiftKey ? -1 : 1, false);
      else select(sw.sel + (e.shiftKey ? -1 : 1));
      return;
    }
    if (!sw.open) return;
    const columns = Math.min(4, sw.items.length);
    if (sw.searching) {
      if (e.key === 'Escape') closeSwitcher();
      else if (e.key === 'Enter') commit();
      else if (e.key === 'Tab') select(sw.sel + (e.shiftKey ? -1 : 1));
      else if (e.key === 'Backspace') { sw.query = sw.query.slice(0, -1); sw.sel = 0; buildSwitcher(); }
      else if (e.key.length === 1 && !e.metaKey && !e.ctrlKey) { sw.query += e.key; sw.sel = 0; buildSwitcher(); }
      else return;
      e.preventDefault();
      return;
    }
    switch (e.code) {
      case 'Escape': closeSwitcher(); break;
      case 'Enter': case 'NumpadEnter': commit(); break;
      case 'ArrowRight': select(sw.sel + 1); break;
      case 'ArrowLeft': select(sw.sel - 1); break;
      case 'ArrowDown': select(sw.sel + columns); break;
      case 'ArrowUp': select(sw.sel - columns); break;
      case 'Space': sw.searching = true; buildSwitcher(); break;
      case 'KeyW': act('close'); break;
      case 'KeyM': act('minimize'); break;
      case 'KeyQ': act('quit'); break;
      default: return;
    }
    e.preventDefault();
  });
  addEventListener('keyup', (e) => {
    if (e.key === 'Alt' && sw.open && !sw.searching) commit();
  });
  // Leaving the page with ⌥ held would otherwise leave the switcher hanging.
  addEventListener('blur', () => { if (sw.open && !sw.searching) closeSwitcher(); });

  // No keyboard: each press steps; it switches a moment after the last one.
  let tryTimer = 0;
  $('#tryButton').addEventListener('click', () => {
    if (mac.classList.contains('locked')) unlock();
    const run = () => {
      if (!sw.open) openSwitcher(1, true); else select(sw.sel + 1);
      clearTimeout(tryTimer);
      tryTimer = setTimeout(commit, 1300);
    };
    if (mac.classList.contains('locked')) setTimeout(run, reduceMotion.matches ? 0 : 450); else run();
  });

  // =========================================================
  // Harbor Dock — only Harbor apps, each linking to its site.
  // =========================================================
  const HARBOR = [
    { id: 'inlet', name: 'Inlet', url: 'https://kaandis.github.io/inlet/', icon: 'assets/inlet-icon.png?v=1' },
    { id: 'ferry', name: 'Ferry', url: 'https://kaandis.github.io/ferry/', icon: 'assets/icon.png?v=1', running: true },
    { id: 'stow', name: 'Stow', url: 'https://kaandis.github.io/stow/', icon: 'assets/stow-icon.png?v=1' },
    { id: 'harbor', name: 'Harbor', url: 'https://kaandis.github.io/harbor/', icon: 'assets/harbor-icon.png?v=3' },
  ];
  const dock = $('#dock');
  const preview = $('#dockPreview');
  const label = $('#dockLabel');
  const previewAnim = [new Spring(0)];
  let previewTimer = 0;
  let hideTimer = 0;

  dock.innerHTML = HARBOR.map((app) => `<a href="${app.url}" data-app="${app.id}" class="${app.running ? 'running' : ''}" aria-label="${app.name}"><img src="${app.icon}" alt="" width="52" height="52"></a>`).join('');

  function iconCenter(a) {
    const box = a.getBoundingClientRect();
    const macBox = mac.getBoundingClientRect();
    return (box.left + box.width / 2 - macBox.left) / k;
  }

  function showDockPreview(a) {
    clearTimeout(hideTimer);
    const windows = WINDOWS.filter((w) => w.app === 'ferry');
    preview.innerHTML = `<div class="dp-head"><img src="assets/icon.png?v=1" alt="">Ferry<span>${t('windows')(windows.length)}</span></div><div class="dp-cards"></div>`;
    windows.forEach((w) => {
      const card = document.createElement('button');
      card.type = 'button';
      card.className = 'dp-card';
      const mini = document.createElement('div');
      mini.className = 'mini';
      const scale = Math.min(138 / w.w, 90 / w.h);
      const clone = w.el.cloneNode(true);
      clone.removeAttribute('style');
      Object.assign(clone.style, { width: `${w.w}px`, height: `${w.h}px`, display: 'block' });
      const holder = document.createElement('div');
      holder.className = 'clone';
      Object.assign(holder.style, { transform: `scale(${scale})`, left: `${(138 - w.w * scale) / 2}px`, top: `${(90 - w.h * scale) / 2}px` });
      holder.append(clone);
      mini.append(holder);
      card.append(mini);
      card.insertAdjacentHTML('beforeend', '<small></small>');
      $('small', card).textContent = w.title[lang];
      card.addEventListener('click', () => { hideDockPreview(); focusWindow(w.id); });
      $('.dp-cards', preview).append(card);
    });
    preview.hidden = false;
    label.hidden = true;
    preview.style.left = `${iconCenter(a) - preview.offsetWidth / 2}px`;
    previewAnim[0].target = 1;
    animate(previewAnim, applyPreview, { response: 0.28, damping: 1, epsilon: 0.002 });
  }

  function applyPreview() {
    const p = Math.max(0, Math.min(1, previewAnim[0].value));
    preview.style.opacity = String(p);
    preview.style.transform = reduceMotion.matches ? 'none' : `translateY(${(1 - p) * 10}px) scale(${0.92 + 0.08 * p})`;
  }

  function hideDockPreview() {
    clearTimeout(previewTimer);
    if (preview.hidden) return;
    previewAnim[0].target = 0;
    animate(previewAnim, applyPreview, { response: 0.28, damping: 1, epsilon: 0.002 }, () => {
      if (previewAnim[0].target === 0) preview.hidden = true;
    });
  }

  $$('a', dock).forEach((a) => {
    a.addEventListener('pointerenter', () => {
      clearTimeout(hideTimer);
      if (a.dataset.app === 'ferry') {
        previewTimer = setTimeout(() => showDockPreview(a), preview.hidden ? 250 : 0);
      } else {
        hideDockPreview();
        label.textContent = `${a.getAttribute('aria-label')} · ${t('visit')}`;
        label.hidden = false;
        label.style.left = `${iconCenter(a)}px`;
      }
    });
    a.addEventListener('pointerleave', () => {
      clearTimeout(previewTimer);
      label.hidden = true;
      hideTimer = setTimeout(hideDockPreview, 220);
    });
    a.addEventListener('click', (e) => {
      if (a.dataset.app === 'ferry') {
        // This is Ferry's own site: the link takes you to the top of it.
        e.preventDefault();
        scrollTo({ top: 0, behavior: reduceMotion.matches ? 'auto' : 'smooth' });
      } else {
        a.target = '_blank';
        a.rel = 'noopener';
      }
    });
  });
  preview.addEventListener('pointerenter', () => clearTimeout(hideTimer));
  preview.addEventListener('pointerleave', () => { hideTimer = setTimeout(hideDockPreview, 200); });

  // =========================================================
  // Lock & unlock
  // =========================================================
  function unlock() {
    mac.classList.remove('locked');
  }
  $('#unlock').addEventListener('click', unlock);

  // =========================================================
  // Start
  // =========================================================
  const saved = store.get('lang');
  // Only trust known values from storage; anything else falls back to the browser language.
  const initial = (saved === 'tr' || saved === 'en') ? saved : ((navigator.language || '').toLowerCase().startsWith('tr') ? 'tr' : 'en');
  setLanguage(initial);
  WINDOWS.forEach(applyWindowAnim);
  langButton.addEventListener('click', () => setLanguage(lang === 'tr' ? 'en' : 'tr'));
})();
