# frozen_string_literal: true

module SlimGraphR
  module MotionPlayer
    module_function

    CSS = <<~'CSS'.freeze
      [data-sgr-motion-root]{font-family:Geist,'Helvetica Neue',Arial,sans-serif}
      [data-sgr-motion-root].sgr-motion-ready [data-motion-item]{opacity:0;transform:translateY(5px);transition:opacity .24s ease,transform .24s ease;pointer-events:none}
      [data-sgr-motion-root].sgr-motion-ready [data-motion-item].is-visible{opacity:1;transform:none;pointer-events:auto}
      [data-sgr-motion-root] [data-motion-item].is-current{filter:drop-shadow(0 0 3px var(--sgr-accent,#b63b18))}
      [data-sgr-motion-root][data-frame="end"] [data-motion-until],
      [data-sgr-motion-root][data-frame="static"] [data-motion-until]{display:none!important}
      [data-sgr-motion-controls]{display:flex;align-items:center;gap:8px;flex-wrap:wrap;padding:12px 16px;border-top:1px solid #d4d4d4}
      [data-sgr-motion-controls] button{min-width:44px;min-height:44px;padding:8px 12px;border:1px solid #a3a3a3;border-radius:5px;background:#fff;color:#20232c;font:600 13px/1 Geist,'Helvetica Neue',Arial,sans-serif;cursor:pointer}
      [data-sgr-motion-controls] button:focus-visible,[data-sgr-motion-root]:focus-visible{outline:3px solid #b63b18;outline-offset:2px}
      [data-sgr-motion-controls] button:disabled{opacity:.42;cursor:not-allowed}
      [data-sgr-motion-count]{font:12px/1.4 ui-monospace,SFMono-Regular,Menlo,monospace;color:#4b5563}
      [data-sgr-motion-status]{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}
      @media(prefers-reduced-motion:reduce){[data-sgr-motion-controls]{display:none!important}[data-motion-item]{opacity:1!important;transform:none!important;transition:none!important}[data-motion-until]{display:none!important}}
      @media print{[data-sgr-motion-controls]{display:none!important}[data-motion-item]{opacity:1!important;transform:none!important}[data-motion-until]{display:none!important}}
    CSS

    JAVASCRIPT = <<~'JS'.freeze
      (() => {
        const controllers = globalThis.__SlimGraphRMotionControllers || new WeakMap();
        globalThis.__SlimGraphRMotionControllers = controllers;
        const boot = (scope = document) => scope.querySelectorAll('[data-sgr-motion-root]').forEach((root) => {
          const existing = controllers.get(root);
          if (existing) return existing.refresh();

          const reduce = matchMedia('(prefers-reduced-motion: reduce)');
          const params = new URLSearchParams(location.search);
          let count = 0, items = [], controls, status, counter;
          let current = 1, timer = null, playing = false;
          const button = (name) => controls.querySelector(`[data-motion-action="${name}"]`);
          const replacements = (step) => items.filter(item => Number(item.dataset.step) <= step)
            .flatMap(item => (item.dataset.motionReplaces || '').split(' ').filter(Boolean));
          const render = (next, announce = false) => {
            current = Math.max(1, Math.min(count, next));
            const hidden = replacements(current);
            items.forEach(item => {
              const visible = Number(item.dataset.step) <= current && !hidden.includes(item.dataset.motionKey);
              item.classList.toggle('is-visible', visible);
              item.classList.toggle('is-current', visible && Number(item.dataset.step) === current);
              item.setAttribute('aria-hidden', visible ? 'false' : 'true');
            });
            root.dataset.stepCurrent = String(current);
            root.dataset.frame = current === count ? 'end' : 'step';
            counter.textContent = String(current);
            button('prev').disabled = current === 1;
            button('next').disabled = current === count;
            if (announce) status.textContent = items.find(item => Number(item.dataset.step) === current)?.getAttribute('aria-label') || `Step ${current} of ${count}`;
          };
          const pause = () => { playing = false; clearTimeout(timer); button('play').setAttribute('aria-pressed', 'false'); };
          const tick = () => { if (!playing) return; if (current >= count) return pause(); render(current + 1, true); timer = setTimeout(tick, 1300); };
          const play = (restart = false) => { if (reduce.matches) return; if (restart || current >= count) render(1, true); playing = true; button('play').setAttribute('aria-pressed', 'true'); clearTimeout(timer); timer = setTimeout(tick, 900); };
          root.addEventListener('click', (event) => {
            const action = event.target.closest('[data-motion-action]')?.dataset.motionAction;
            if (!action) return;
            if (action === 'prev') { pause(); render(current - 1, true); }
            if (action === 'next') { pause(); render(current + 1, true); }
            if (action === 'play') playing ? pause() : play();
            if (action === 'replay') { pause(); play(true); }
          });
          root.addEventListener('keydown', (event) => {
            if (event.key === 'ArrowLeft') { event.preventDefault(); pause(); render(current - 1, true); }
            if (event.key === 'ArrowRight') { event.preventDefault(); pause(); render(current + 1, true); }
            if (event.key === 'Home') { event.preventDefault(); pause(); render(1, true); }
            if (event.key === 'End') { event.preventDefault(); pause(); render(count, true); }
            if (event.key === ' ') { event.preventDefault(); playing ? pause() : play(); }
            if (event.key.toLowerCase() === 'r') { event.preventDefault(); pause(); play(true); }
          });
          const staticFrame = () => { pause(); render(count); root.dataset.frame = 'static'; controls.hidden = true; };
          const refresh = () => {
            count = Number(root.dataset.stepCount);
            items = [...root.querySelectorAll('[data-motion-item]')];
            controls = root.querySelector('[data-sgr-motion-controls]');
            status = root.querySelector('[data-sgr-motion-status]');
            counter = root.querySelector('[data-sgr-motion-current]');
            root.dataset.motionReady = 'true';
            root.classList.add('sgr-motion-ready');
            if (reduce.matches || params.get('motion') === 'static') staticFrame();
            else if (params.get('motion') === 'step') {
              controls.hidden = true;
              const requested = Number(params.get('step'));
              render(Number.isSafeInteger(requested) && requested >= 1 && requested <= count ? requested : 1);
            } else {
              controls.hidden = false;
              render(current);
            }
          };
          const controller = { refresh, pause };
          controllers.set(root, controller);
          reduce.addEventListener('change', () => reduce.matches ? staticFrame() : (controls.hidden = false, render(current)));
          document.addEventListener('visibilitychange', () => { if (document.hidden) pause(); });
          refresh();
          if (!reduce.matches && params.get('motion') !== 'static' && params.get('motion') !== 'step' && root.dataset.motionMode === 'reveal') play();
        });
        globalThis.SlimGraphRMotion = { boot };
        boot();
      })();
    JS

    def document(presentation, mode:)
      diagram = presentation.diagram
      light = diagram.style_profile.light.fetch(:paper)
      dark = diagram.style_profile.dark.fetch(:paper)
      background = diagram.theme == :dark ? dark : light
      auto = diagram.theme == :auto ? "@media(prefers-color-scheme:dark){html,body{background:#{dark}}}" : ''
      body = fragment(presentation, mode: mode, include_script: true, include_style: false)
      %(<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>#{CGI.escapeHTML(diagram.title)}</title><style>html,body{margin:0;min-height:100%;background:#{background}}#{auto}#{CSS}</style></head><body>#{body}</body></html>)
    end

    def static_document(presentation)
      diagram = presentation.diagram
      light = diagram.style_profile.light.fetch(:paper)
      dark = diagram.style_profile.dark.fetch(:paper)
      background = diagram.theme == :dark ? dark : light
      auto = diagram.theme == :auto ? "@media(prefers-color-scheme:dark){html,body{background:#{dark}}}" : ''
      svg = presentation.to_svg
      label = CGI.escapeHTML(diagram.title)
      body = %(<div class="sgr-scroll-container" data-sgr-scroll-container="true" role="region" tabindex="0" aria-label="#{label}" style="display:block;box-sizing:border-box;width:100%;max-width:100%;overflow-x:auto;overflow-y:hidden;overscroll-behavior-inline:contain">#{svg}</div>)
      %(<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>#{label}</title><style>html,body{margin:0;min-height:100%;background:#{background}}#{auto}</style></head><body>#{body}</body></html>)
    end

    def fragment(presentation, mode:, include_script:, include_style: true)
      diagram, storyboard = presentation.diagram, presentation.storyboard
      svg = presentation.motion_svg
      label = CGI.escapeHTML(diagram.title)
      controls = <<~HTML
        <div data-sgr-motion-controls role="group" aria-label="Diagram playback controls">
          <button type="button" data-motion-action="prev">Previous</button>
          <button type="button" data-motion-action="play" aria-pressed="false">Play / pause</button>
          <button type="button" data-motion-action="next">Next</button>
          <button type="button" data-motion-action="replay">Replay</button>
          <span data-sgr-motion-count>Step <span data-sgr-motion-current>1</span> of #{storyboard.steps.size}</span>
        </div>
      HTML
      script = include_script ? "<script>#{JAVASCRIPT.gsub(%r{</(?=script)}i, '<\\/')}</script>" : ''
      <<~HTML
        <section data-sgr-motion-root data-motion-mode="#{mode}" data-step-count="#{storyboard.steps.size}" data-step-current="1" data-frame="step" tabindex="0" aria-label="#{label}">
          #{include_style ? "<style>#{CSS}</style>" : ''}
          <div class="sgr-scroll-container" data-sgr-scroll-container="true" role="region" tabindex="0" aria-label="#{label}" style="display:block;box-sizing:border-box;width:100%;max-width:100%;overflow-x:auto;overflow-y:hidden;overscroll-behavior-inline:contain">#{svg}</div>
          #{controls}
          <p data-sgr-motion-status role="status" aria-live="polite" aria-atomic="true"></p>
          <noscript><style>[data-sgr-motion-controls]{display:none!important}[data-motion-until]{display:none!important}</style></noscript>
        </section>
        #{script}
      HTML
    end
  end
end
