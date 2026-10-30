const ATLAS =
  new URL("./assets/residents-original-v2.png", import.meta.url).href;
export const CREW = Object.freeze([
  Object.freeze({
    id: "mio",
    name: "ミオ",
    role: "整備士",
    cell: 0,
    join: 1,
    work: "足場を点検中",
    chat: "直せるものがあると、わくわくするね。",
    pose: [
      { transform: "rotate(-3deg)" },
      { transform: "rotate(6deg)" },
      { transform: "rotate(-3deg)" },
    ],
  }),
  Object.freeze({
    id: "gen",
    name: "ゲン",
    role: "菜園係",
    cell: 50,
    join: 2,
    work: "苗と菜園の手入れ",
    chat: "小さな芽も、明日のごちそうになるぞ。",
    pose: [
      { transform: "rotate(0deg) scaleY(1)" },
      { transform: "rotate(-7deg) scaleY(.94)" },
      { transform: "rotate(0deg) scaleY(1)" },
    ],
  }),
  Object.freeze({
    id: "riku",
    name: "リク",
    role: "海図係",
    cell: 100,
    join: 3,
    work: "海図を見比べ中",
    chat: "この灯りを目印に、帰れる場所をつくろう！",
    pose: [
      { transform: "rotate(-4deg) translateX(-1px)" },
      { transform: "rotate(4deg) translateX(2px)" },
      { transform: "rotate(-4deg) translateX(-1px)" },
    ],
  }),
]);

const say = {
  collect: ["mio", "いい流木！手入れすれば使えるよ。"],
  build: ["mio", "足場が広がった！道具を運ぼう。"],
  "build-warehouse": ["mio", "これで大事な資材を守れるね。"],
  plant: ["gen", "ひと粒ずつ、明日の食卓じゃ。"],
  harvest: ["gen", "よく育った！みんなで食べよう。"],
  "donate-food": ["gen", "温かい食卓は、みんなの元気じゃ。"],
  "share-food": ["gen", "やさしいおすそ分け、ありがとう。"],
  invite: ["riku", "仲間が増えた！居場所を案内するよ。"],
  claim: ["riku", "ひとつ達成！この灯りを育てよう。"],
};

export function createResidentScene(
  { main, board, play, roster, feedback, onTalk, onFlavor },
) {
  const abort = new AbortController();
  const signal = abort.signal;
  const media = matchMedia("(prefers-reduced-motion: reduce)");
  const wide = matchMedia("(min-width: 721px)");
  const layer = document.createElement("div");
  layer.className = "crew-scene";
  layer.setAttribute("aria-hidden", "true");
  play.append(layer);
  const lantern = document.createElement("span");
  lantern.className = "crew-lantern";
  layer.append(lantern);
  const actors = new Map(), cards = new Map();
  let tiles = [],
    population = 1,
    disposed = false,
    timer = null,
    toastTimer = null,
    paused = true,
    active = true,
    currentFlavor = null;
  const image = new Image();
  image.onload = () => {
    if (!disposed) main.dataset.residentArt = "ready";
  };
  image.onerror = () => {
    if (disposed) return;
    main.dataset.residentArt = "missing";
    const note = main.querySelector("#resident-art-note");
    if (note) {
      note.hidden = false;
      note.textContent =
        "住民画像を読み込めません。会話と集落の操作は続けられます。";
    }
  };
  image.src = ATLAS;

  function art(crew, cls) {
    const el = document.createElement("span");
    el.className = `resident-art ${cls}`;
    el.style.setProperty("--resident-cell", `${crew.cell}%`);
    const fallback = document.createElement("span");
    fallback.className = "resident-fallback";
    fallback.textContent = crew.name[0];
    el.append(fallback);
    return el;
  }
  for (const crew of CREW) {
    const card = document.createElement("button");
    card.type = "button";
    card.className = "crew-card";
    card.setAttribute("aria-label", `${crew.name} ${crew.role}と話す`);
    const name = document.createElement("strong");
    name.textContent = crew.name;
    const role = document.createElement("span");
    role.textContent = crew.role;
    const activity = document.createElement("small");
    card.append(art(crew, "crew-portrait"), name, role, activity);
    card.addEventListener("click", () => {
      onTalk(`${crew.name}「${crew.chat}」`);
      showFlavor(crew, crew.chat);
    }, { signal });
    roster.append(card);
    cards.set(crew.id, { card, activity });
  }

  function cancelMotion(actor) {
    if (actor.animation) {
      actor.animation.onfinish = null;
      actor.animation.cancel();
      actor.animation = null;
    }
  }
  function pose(actor, walking = false, once = false) {
    cancelMotion(actor);
    if (disposed || media.matches || paused || !actor.art.animate) return;
    const frames = walking
      ? [{ transform: "rotate(-4deg) translateY(0)" }, {
        transform: "rotate(4deg) translateY(-2px)",
      }, { transform: "rotate(-4deg) translateY(0)" }]
      : actor.crew.pose;
    actor.animation = actor.art.animate(frames, {
      duration: walking ? 240 : once ? 650 : 2200 + actor.crew.join * 500,
      iterations: walking ? 7 : once ? 1 : Infinity,
      easing: "ease-in-out",
    });
    if (walking || once) actor.animation.onfinish = () => pose(actor);
  }
  function place(actor, tile, walking = false) {
    actor.tile = { x: tile.x, y: tile.y };
    const same = [...actors.values()].filter((a) =>
      a !== actor && a.tile?.x === tile.x && a.tile?.y === tile.y
    );
    const offset = same.length ? .25 : .76;
    actor.root.style.left = `${(tile.x + offset) * 20}%`;
    actor.root.style.top = `${(tile.y + .96) * 20}%`;
    if (walking) pose(actor, true);
  }
  function syncSize() {
    if (disposed || !board.clientWidth || !play.clientHeight) return;
    const b = board.getBoundingClientRect(), p = play.getBoundingClientRect();
    layer.style.left = `${b.left - p.left}px`;
    layer.style.top = `${b.top - p.top}px`;
    layer.style.width = `${b.width}px`;
    layer.style.height = `${b.height}px`;
    layer.style.setProperty("--scene-size", `${b.width}px`);
  }
  function sceneVisible() {
    return active && !document.hidden &&
      (wide.matches || main.dataset.view === "board");
  }
  function setPaused() {
    const next = !sceneVisible();
    if (next === paused) return;
    paused = next;
    if (timer !== null) {
      clearInterval(timer);
      timer = null;
    }
    for (const animation of layer.getAnimations({ subtree: true })) {
      if (paused) animation.pause();
      else if (!media.matches) animation.play();
    }
    if (!paused) {
      for (const actor of actors.values()) if (!actor.animation) pose(actor);
      timer = setInterval(wander, 6200);
      syncSize();
    }
  }
  function wander() {
    if (disposed || paused || media.matches) return;
    for (const actor of actors.values()) {
      const near = tiles.filter((t) =>
        Math.abs(t.x - actor.tile.x) + Math.abs(t.y - actor.tile.y) === 1 &&
        ![...actors.values()].some((a) =>
          a !== actor && a.tile?.x === t.x && a.tile?.y === t.y
        )
      );
      if (!near.length) continue;
      const preferred = near.find((t) =>
        t.kind === ({ mio: "deck", gen: "garden", riku: "dock" }[actor.crew.id])
      );
      place(actor, preferred ?? near[(actor.steps++) % near.length], true);
    }
  }
  function showFlavor(crew, line) {
    if (disposed) return;
    if (toastTimer !== null) clearTimeout(toastTimer);
    currentFlavor = { crew, line };
    paintFeedback(crew, `「${line}」`);
    onFlavor(currentFlavor);
    toastTimer = setTimeout(() => {
      toastTimer = null;
      currentFlavor = null;
      paintFeedback(CREW[0], CREW[0].work);
      onFlavor(null);
    }, 3200);
  }
  function paintFeedback(crew, line) {
    feedback.replaceChildren(
      art(crew, "crew-mini"),
      document.createTextNode(`${crew.name} ${line}`),
    );
    feedback.dataset.active = "true";
  }
  function update(state) {
    if (disposed) return;
    population = state.residents;
    tiles = state.tiles.map((t) => ({ ...t }));
    for (const crew of CREW) {
      const joined = population >= crew.join;
      const { card, activity } = cards.get(crew.id);
      card.disabled = !joined;
      activity.textContent = joined ? crew.work : `住民${crew.join}人で合流`;
      if (!joined) {
        const old = actors.get(crew.id);
        if (old) {
          cancelMotion(old);
          old.root.remove();
          actors.delete(crew.id);
        }
        continue;
      }
      let actor = actors.get(crew.id);
      if (!actor) {
        const root = document.createElement("span");
        root.className = "crew-actor";
        root.dataset.name = crew.name;
        const sprite = art(crew, "crew-sprite");
        root.append(sprite);
        layer.append(root);
        actor = {
          root,
          art: sprite,
          crew,
          tile: null,
          steps: 0,
          animation: null,
        };
        actors.set(crew.id, actor);
        place(actor, tiles[(crew.join - 1) % tiles.length]);
        pose(actor);
      } else if (
        !tiles.some((t) => t.x === actor.tile.x && t.y === actor.tile.y)
      ) {
        place(actor, tiles[0]);
      }
    }
    const dock = tiles.find((t) => t.kind === "dock");
    lantern.hidden = state.claimed.length < 3;
    if (dock) {
      lantern.style.left = `${(dock.x + .5) * 20}%`;
      lantern.style.top = `${(dock.y + .4) * 20}%`;
    }
    setPaused();
    syncSize();
    if (currentFlavor) onFlavor(currentFlavor);
    else paintFeedback(CREW[0], CREW[0].work);
  }
  function react(action) {
    const entry = say[action.type];
    if (!entry || disposed) return;
    const crew = CREW.find((c) => c.id === entry[0] && population >= c.join) ??
      CREW[0];
    showFlavor(crew, entry[1]);
    const actor = actors.get(crew.id);
    if (actor && !paused && !media.matches) {
      pose(actor, false, true);
      // The art animation is decorative; resource changes have already committed.
    }
  }
  const size = new ResizeObserver(syncSize);
  size.observe(board);
  const railSize = new ResizeObserver(() => {
    if (feedback.clientHeight) {
      main.style.setProperty(
        "--crew-feedback-room",
        `${feedback.clientHeight + 8}px`,
      );
    }
  });
  railSize.observe(feedback);
  document.addEventListener("visibilitychange", setPaused, { signal });
  wide.addEventListener("change", setPaused, { signal });
  media.addEventListener("change", () => {
    for (const a of actors.values()) {
      cancelMotion(a);
      pose(a);
    }
  }, { signal });
  globalThis.addEventListener("pagehide", (event) => {
    if (event.persisted) {
      active = false;
      setPaused();
    } else dispose();
  }, { signal });
  globalThis.addEventListener("pageshow", () => {
    active = true;
    setPaused();
  }, { signal });
  function dispose() {
    if (disposed) return;
    disposed = true;
    abort.abort();
    size.disconnect();
    railSize.disconnect();
    if (timer !== null) clearInterval(timer);
    if (toastTimer !== null) clearTimeout(toastTimer);
    for (const a of actors.values()) cancelMotion(a);
    for (const animation of layer.getAnimations({ subtree: true })) {
      animation.cancel();
    }
    actors.clear();
    cards.clear();
    layer.remove();
    roster.replaceChildren();
    feedback.replaceChildren();
    delete feedback.dataset.active;
    delete main.dataset.residentScene;
    image.onload = null;
    image.onerror = null;
  }
  main.dataset.residentScene = "ready";
  return { update, react, refreshVisibility: setPaused, dispose };
}
