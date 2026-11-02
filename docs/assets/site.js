/* DSH GO MAC — motion system */
(() => {
  const doc = document;
  const html = doc.documentElement;
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const fine = window.matchMedia('(pointer: fine)').matches;
  const hasGsap = typeof window.gsap !== 'undefined';
  let lenis = null;
  if (hasGsap && window.ScrollTrigger) gsap.registerPlugin(ScrollTrigger);
  if (!hasGsap) html.classList.remove('js');

  const $ = (s, r = doc) => r.querySelector(s);
  const $$ = (s, r = doc) => Array.from(r.querySelectorAll(s));

  /* ---------- loader ---------- */
  const loader = $('#loader');
  const loadCount = $('#loadCount');
  const loadBar = $('#loadBar');
  const preloader = {n: 0};
  const fontsReady = doc.fonts && doc.fonts.ready ? doc.fonts.ready : Promise.resolve();
  const ready = Promise.race([fontsReady, new Promise(r => setTimeout(r, 900))]);

  function hideLoader() {
    if (!loader) return;
    loader.style.transition = 'opacity .7s cubic-bezier(.22,1,.36,1), visibility .7s';
    loader.style.opacity = '0';
    loader.style.visibility = 'hidden';
    setTimeout(() => loader.remove(), 800);
  }

  if (hasGsap && !reduced) {
    gsap.to(preloader, {
      n: 100, duration: 1.15, ease: 'power2.inOut',
      onUpdate: () => { if (loadCount) loadCount.textContent = String(Math.round(preloader.n)).padStart(2, '0'); },
      onComplete: () => {
        if (loadBar) gsap.to(loadBar, {scaleX: 1, duration: .35, transformOrigin: 'left', ease: 'power2.out'});
      }
    });
    if (loadBar) gsap.fromTo(loadBar, {scaleX: 0}, {scaleX: 1, duration: 1.2, transformOrigin: 'left', ease: 'power2.inOut'});
  } else {
    hideLoader();
  }

  /* ---------- intro ---------- */
  const hero = $('#hero');
  function intro() {
    if (!hasGsap || reduced) { hideLoader(); return; }
    const tl = gsap.timeline({defaults: {ease: 'expo.out'}});
    tl.set('.hero [data-hero="eyebrow"], .hero [data-hero="sub"], .hero [data-hero="cta"], .hero [data-hero="meta"], .hero [data-hero="card"]', {opacity: 0})
      .set('.hero h1 .line', {opacity: 1})
      .set('.hero h1 .line > span', {yPercent: 112})
      .set('#nav', {yPercent: -100, opacity: 0})
      .add(() => hideLoader(), 0.05)
      .to('#nav', {yPercent: 0, opacity: 1, duration: 1.1}, 0.15)
      .to('[data-hero="eyebrow"]', {opacity: 1, y: 0, duration: .9}, 0.35)
      .to('.hero h1 .line > span', {yPercent: 0, duration: 1.15, stagger: .11}, 0.35)
      .to('[data-hero="sub"]', {opacity: 1, y: 0, duration: 1}, 0.8)
      .to('[data-hero="cta"]', {opacity: 1, y: 0, duration: 1}, 0.95)
      .to('[data-hero="meta"]', {opacity: 1, y: 0, duration: .9, stagger: .08}, 1.05)
      .to('[data-hero="card"]', {opacity: 1, y: 0, rotateX: 0, duration: 1.35}, 0.65)
      .fromTo('#scene', {opacity: 0}, {opacity: .8, duration: 1.8}, 0.4);
    gsap.set('[data-hero="sub"], [data-hero="cta"]', {y: 16});
    gsap.set('.hero [data-hero="meta"]', {y: 10});
    gsap.set('[data-hero="card"]', {y: 46, rotateX: 7, transformPerspective: 1000});
  }

  ready.then(() => {
    if (!hasGsap) { hideLoader(); return; }
    if (window.Lenis && !reduced && window.matchMedia('(pointer:fine)').matches && window.innerWidth > 900) {
      lenis = new Lenis({duration: 1.15, smoothWheel: true, wheelMultiplier: 1, touchMultiplier: 1.2});
      lenis.on('scroll', window.ScrollTrigger ? ScrollTrigger.update : () => {});
      gsap.ticker.add(time => lenis.raf(time * 1000));
      gsap.ticker.lagSmoothing(0);
    }
    intro();
    if (!reduced) {
      /* reveal */
      $$('[data-reveal]').forEach(el => {
        gsap.fromTo(el, {opacity: 0, y: 30}, {
          opacity: 1, y: 0, duration: 1, ease: 'expo.out',
          scrollTrigger: {trigger: el, start: 'top 88%', once: true}
        });
      });
      /* film */
      const film = $('.film');
      if (film) {
        gsap.fromTo(film, {clipPath: 'inset(8% 5% 8% 5%)'}, {
          clipPath: 'inset(0% 0% 0% 0%)', duration: 1.5, ease: 'expo.out',
          scrollTrigger: {trigger: film, start: 'top 78%', once: true}
        });
        gsap.fromTo(film.querySelector('img'), {scale: 1.08}, {
          scale: 1, duration: 1.7, ease: 'expo.out',
          scrollTrigger: {trigger: film, start: 'top 78%', once: true}
        });
      }
      /* section headings: line mask */
      $$('.section-head h2, .install h2').forEach(h => {
        gsap.fromTo(h, {clipPath: 'inset(0 0 100% 0)'}, {
          clipPath: 'inset(0 0 0% 0)', duration: 1.25, ease: 'expo.out',
          scrollTrigger: {trigger: h, start: 'top 86%', once: true}
        });
      });
      /* sparkline draws with the run */
      const spark = $('.console-spark polyline');
      if (spark) {
        gsap.fromTo(spark, {strokeDasharray: 620, strokeDashoffset: 620}, {
          strokeDashoffset: 0, duration: 1.6, ease: 'power2.out',
          scrollTrigger: {trigger: '#surface', start: 'top 70%', once: true}
        });
      }
      /* proof parallax */
      $$('.proof-media img').forEach(img => {
        gsap.fromTo(img, {yPercent: -3}, {
          yPercent: 3, ease: 'none',
          scrollTrigger: {trigger: img.closest('.proof'), start: 'top bottom', end: 'bottom top', scrub: 1}
        });
      });
      /* parallax */
      $$('[data-parallax]').forEach(el => {
        const amt = parseFloat(el.dataset.parallax || '0.06');
        gsap.fromTo(el, {yPercent: amt * 60}, {
          yPercent: amt * -90, ease: 'none',
          scrollTrigger: {trigger: el, start: 'top bottom', end: 'bottom top', scrub: .8}
        });
      });
      /* engine frame */
      const frame = $('.engine-frame');
      if (frame) {
        gsap.fromTo(frame, {opacity: 0, y: 40, rotateY: -8, transformPerspective: 1200}, {
          opacity: 1, y: 0, rotateY: -3, duration: 1.6, ease: 'expo.out',
          scrollTrigger: {trigger: frame, start: 'top 80%', once: true}
        });
      }
      /* footer word */
      gsap.fromTo('.footer-word', {xPercent: 3}, {
        xPercent: -5, ease: 'none',
        scrollTrigger: {trigger: '.footer', start: 'top bottom', end: 'bottom top', scrub: 1}
      });
    }

    /* surface pin */
    if (hasGsap && window.ScrollTrigger) {
      const mm = gsap.matchMedia();
      /* horizontal proof */
      mm.add('(min-width: 1061px) and (prefers-reduced-motion: no-preference)', () => {
        const track = $('#evidenceTrack');
        const pin = $('#evidencePin');
        if (!track || !pin) return;
        const distance = () => Math.max(0, track.scrollWidth - window.innerWidth + 80);
        const tween = gsap.to(track, {
          x: () => -distance(), ease: 'none',
          scrollTrigger: {
            trigger: pin, start: 'top top', end: () => '+=' + distance(),
            pin: true, scrub: .8, anticipatePin: 1, invalidateOnRefresh: true
          }
        });
        return () => { tween.scrollTrigger && tween.scrollTrigger.kill(); tween.kill(); };
      });
      mm.add('(min-width: 1061px) and (prefers-reduced-motion: no-preference)', () => {
        const consoleEl = $('#console');
        const rows = $$('#consoleRows .crow');
        const tabs = $$('.console-tabs span');
        const diff = $('#consoleDiff');
        const timeEl = $('#mTime'), stepsEl = $('#mSteps'), filesEl = $('#mFiles');
        const num = {t: 0, s: 0, f: 0};
        const fmt = v => {
          const h = Math.floor(v / 3600), m = Math.floor((v % 3600) / 60), s = Math.floor(v % 60);
          return `${h}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
        };
        const tl = gsap.timeline({
          scrollTrigger: {
            trigger: '#surface', start: 'top top', end: 'bottom bottom',
            scrub: .6,
            onUpdate(self) {
              const p = self.progress;
              const idx = p > .78 ? 4 : p > .62 ? 3 : p > .42 ? 2 : p > .2 ? 1 : 0;
              rows.forEach((r, i) => r.classList.toggle('on', i <= idx));
              const tabOn = p > .58 ? 1 : 0;
              tabs.forEach((t, i) => t.classList.toggle('on', i === tabOn));
              if (diff) diff.style.display = p > .58 ? 'block' : 'none';
              const rowsEl = doc.getElementById('consoleRows');
              if (rowsEl) rowsEl.style.display = p > .58 ? 'none' : 'grid';
              if (consoleEl) consoleEl.classList.toggle('toast', p > .84);
              if (stepsEl) stepsEl.textContent = String(Math.round(122 * Math.min(1, p / .75)));
              if (filesEl) filesEl.textContent = String(Math.round(Math.min(1, Math.max(0, (p - .55) / .2))));
              if (timeEl) timeEl.textContent = fmt(2 * 3600 + 1 * 60 + 57 * Math.min(1, p / .85));
            }
          }
        });
        return () => {
          if (stepsEl) stepsEl.textContent = '122';
          if (filesEl) filesEl.textContent = '1';
          if (timeEl) timeEl.textContent = '2:01:57';
          if (diff) diff.style.display = 'none';
          const rowsEl = doc.getElementById('consoleRows');
          if (rowsEl) rowsEl.style.display = 'grid';
        };
      });
      mm.add('(max-width: 1060px), (prefers-reduced-motion: reduce)', () => {
        $$('#consoleRows .crow').forEach(r => r.classList.add('on'));
        const c = $('#console'); if (c) c.style.opacity = '1';
      });

    }

    /* hosts */
    const notes = {
      official: '不迁移、不复制。读的还是 <code style="font-family:var(--mono)">~/.dsh</code>，官方客户端随时可以继续用。',
      bundled: 'Node 24 + DSH 装进 App。首次使用安装约 750 MB 运行时，之后离线也能起引擎。',
      remote: '同一套界面连另一台机器。SSH（密码/私钥、TOFU）或 DSH Remote，手机版也能反向接管这台 Mac。'
    };
    $$('.host').forEach(btn => {
      btn.addEventListener('click', () => {
        $$('.host').forEach(b => { b.classList.remove('on'); b.setAttribute('aria-selected','false'); });
        btn.classList.add('on'); btn.setAttribute('aria-selected','true');
        const note = $('#hostNote'); if (note) note.innerHTML = notes[btn.dataset.host] || '';
      });
    });

    /* section rail */
    const railLinks = $$('.rail a');
    if (railLinks.length && window.ScrollTrigger) {
      const ids = ['evidence','surface','engine','native','install'];
      ids.forEach(id => {
        const el = doc.getElementById(id);
        if (!el) return;
        ScrollTrigger.create({
          trigger: el, start: 'top 55%', end: 'bottom 45%',
          onToggle: self => {
            if (!self.isActive) return;
            railLinks.forEach(a => a.classList.toggle('on', a.dataset.rail === id));
            const rail = doc.querySelector('.rail');
            if (rail) rail.classList.toggle('hide', id === 'evidence');
          }
        });
      });
    }

    /* hero recedes on scroll */
    if (window.ScrollTrigger && !reduced) {
      gsap.to('.hero-copy', {
        yPercent: -5, opacity: .35, ease: 'none',
        scrollTrigger: {trigger: '#hero', start: 'top top', end: 'bottom top', scrub: .6}
      });
      gsap.to('.hero-shot', {
        yPercent: -9, scale: 1.03, ease: 'none',
        scrollTrigger: {trigger: '#hero', start: 'top top', end: 'bottom top', scrub: .6}
      });
    }

    /* pins were added after load: recalculate the whole layout once settled */
    if (window.ScrollTrigger) {
      requestAnimationFrame(() => ScrollTrigger.refresh());
      setTimeout(() => ScrollTrigger.refresh(), 450);
      window.addEventListener('load', () => ScrollTrigger.refresh(), {once: true});
    }

    /* nav + progress */
    const nav = $('#nav'), progress = $('#navProgress');
    let lastY = window.scrollY;
    function onScroll() {
      const y = window.scrollY;
      if (nav) {
        nav.classList.toggle('is-scrolled', y > 40);
        nav.classList.toggle('is-hidden', y > lastY && y > 420);
      }
      lastY = y;
      if (progress) {
        const max = doc.documentElement.scrollHeight - window.innerHeight;
        progress.style.transform = `scaleX(${max > 0 ? Math.min(1, y / max) : 0})`;
      }
    }
    window.addEventListener('scroll', onScroll, {passive: true});
    onScroll();

    /* mobile menu */
    const menuBtn = $('#menuBtn'), menu = $('#menu');
    const closeMenu = () => { if (!menu) return; menu.classList.remove('open'); menuBtn && menuBtn.classList.remove('open'); menuBtn && menuBtn.setAttribute('aria-expanded','false'); menu && menu.setAttribute('aria-hidden','true'); doc.body.style.overflow=''; };
    if (menuBtn && menu) {
      menuBtn.addEventListener('click', () => {
        const open = !menu.classList.contains('open');
        menu.classList.toggle('open', open); menuBtn.classList.toggle('open', open);
        menuBtn.setAttribute('aria-expanded', String(open)); menu.setAttribute('aria-hidden', String(!open));
        doc.body.style.overflow = open ? 'hidden' : '';
      });
      $$('#menu a').forEach(a => a.addEventListener('click', closeMenu));
      window.addEventListener('keydown', e => { if (e.key === 'Escape') closeMenu(); });
    }

    /* anchors */
    $$('a[href^="#"]').forEach(a => {
      a.addEventListener('click', e => {
        const id = a.getAttribute('href');
        if (!id || id === '#') return;
        const target = $(id); if (!target) return;
        e.preventDefault();
        closeMenu();
        if (lenis) lenis.scrollTo(target, {offset: 0, duration: 1.1});
        else target.scrollIntoView({behavior: reduced ? 'auto' : 'smooth', block: 'start'});
      });
    });

    /* copy */
    const copyBtn = $('#copyCmd');
    if (copyBtn) {
      copyBtn.addEventListener('click', async () => {
        const cmd = 'brew install --cask BillWGong/tap/dsh-go-mac';
        try { await navigator.clipboard.writeText(cmd); copyBtn.textContent = '已复制'; }
        catch { copyBtn.textContent = '复制失败'; }
        setTimeout(() => { copyBtn.textContent = '复制命令'; }, 1800);
      });
    }

    /* cursor + magnetic */
    if (fine && !reduced) {
      const cursor = $('#cursor');
      if (cursor) {
        const xTo = gsap.quickTo(cursor, 'x', {duration: .35, ease: 'power3'});
        const yTo = gsap.quickTo(cursor, 'y', {duration: .35, ease: 'power3'});
        window.addEventListener('pointermove', e => { cursor.classList.add('is-active'); xTo(e.clientX); yTo(e.clientY); }, {passive: true});
        $$('a, button, [data-magnetic]').forEach(el => {
          el.addEventListener('pointerenter', () => cursor.classList.add('grow'));
          el.addEventListener('pointerleave', () => cursor.classList.remove('grow'));
        });
      }
      $$('[data-magnetic]').forEach(el => {
        const strength = 14;
        el.addEventListener('pointermove', e => {
          const r = el.getBoundingClientRect();
          const dx = (e.clientX - r.left - r.width / 2) / r.width;
          const dy = (e.clientY - r.top - r.height / 2) / r.height;
          gsap.to(el, {x: dx * strength, y: dy * strength, duration: .5, ease: 'power3.out'});
        });
        el.addEventListener('pointerleave', () => gsap.to(el, {x: 0, y: 0, duration: .7, ease: 'elastic.out(1,.5)'}));
      });
    }
  });

  /* ---------- three.js trace field ---------- */
  if (!reduced && window.innerWidth > 860) {
    const canvas = $('#scene');
    if (canvas) {
      import('./scene.js').then(({initScene}) => {
        const ctrl = initScene(canvas);
        if (ctrl) canvas.style.opacity = '.8';
      }).catch(() => {});
    }
  }
})();
