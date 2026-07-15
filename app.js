"use strict";

const state = {
  data: { videos: [], websites: [], designs: [], photos: [] },
  filters: { videos: "all", websites: "all", designs: "all", photos: "all" },
  lightbox: { type: null, item: null },
};

const elements = {};

document.addEventListener("DOMContentLoaded", () => {
  elements.loading = document.querySelector("#loading");
  elements.loadingValue = document.querySelector("#loading-value");
  elements.loadingBar = document.querySelector("#loading-bar");
  elements.site = document.querySelector("#site");
  elements.stickyHeader = document.querySelector("#sticky-header");
  elements.scrollTop = document.querySelector("#scroll-top");
  elements.lightbox = document.querySelector("#lightbox");
  elements.lightboxContent = document.querySelector("#lightbox-content");

  bindNavigation();
  bindFilters();
  bindLightbox();
  loadPortfolio();
});

async function loadPortfolio() {
  let progress = 0;
  const interval = window.setInterval(() => {
    if (progress < 90) {
      progress = Math.min(90, progress + Math.random() * 5);
      updateProgress(progress);
    }
  }, 100);

  try {
    const response = await fetch(`data/all.json?v=${Date.now()}`, { cache: "no-store" });
    if (!response.ok) throw new Error(`Erreur HTTP ${response.status}`);

    const result = await response.json();
    state.data = {
      videos: Array.isArray(result.videos) ? result.videos : [],
      websites: Array.isArray(result.websites) ? result.websites : [],
      designs: Array.isArray(result.designs) ? result.designs : [],
      photos: Array.isArray(result.photos) ? result.photos : [],
    };

    renderAll();
    updateProgress(100);
    window.setTimeout(() => {
      elements.loading.classList.add("is-hidden");
      elements.site.classList.remove("is-hidden");
    }, 600);
  } catch (error) {
    showLoadError(error);
  } finally {
    window.clearInterval(interval);
  }
}

function updateProgress(value) {
  const rounded = Math.round(value);
  elements.loadingValue.textContent = `${rounded}%`;
  elements.loadingBar.style.width = `${value}%`;
}

function showLoadError(error) {
  console.error("Erreur lors du chargement des données :", error);
  const localHint = window.location.protocol === "file:"
    ? "Le navigateur bloque les fichiers JSON ouverts directement. Lancez apercu.bat pour tester le site."
    : "Vérifiez que le dossier data et le fichier all.json ont bien été envoyés sur l’hébergement.";

  elements.loading.innerHTML = "";
  const box = document.createElement("div");
  box.className = "error-state";
  const title = document.createElement("strong");
  title.textContent = "Impossible de charger le portfolio.";
  const hint = document.createElement("p");
  hint.textContent = localHint;
  box.append(title, hint);
  elements.loading.append(box);
}

function bindNavigation() {
  document.querySelectorAll("[data-scroll]").forEach((button) => {
    button.addEventListener("click", () => {
      document.getElementById(button.dataset.scroll)?.scrollIntoView({ behavior: "smooth", block: "start" });
    });
  });

  elements.scrollTop.addEventListener("click", () => window.scrollTo({ top: 0, behavior: "smooth" }));
  window.addEventListener("scroll", () => {
    const visible = window.scrollY > 300;
    elements.stickyHeader.classList.toggle("visible", visible);
    elements.scrollTop.classList.toggle("visible", visible);
  }, { passive: true });
}

function bindFilters() {
  document.querySelectorAll("[data-filter-group]").forEach((group) => {
    const key = group.dataset.filterGroup;
    group.querySelectorAll("[data-filter]").forEach((button) => {
      button.addEventListener("click", () => {
        state.filters[key] = button.dataset.filter;
        group.querySelectorAll("[data-filter]").forEach((candidate) => {
          const active = candidate === button;
          candidate.classList.toggle("button-primary", active);
          candidate.classList.toggle("button-outline", !active);
        });
        renderSection(key);
      });
    });
  });
}

function bindLightbox() {
  document.querySelector("#lightbox-close").addEventListener("click", closeLightbox);
  document.querySelector("#lightbox-prev").addEventListener("click", (event) => {
    event.stopPropagation();
    navigateLightbox(-1);
  });
  document.querySelector("#lightbox-next").addEventListener("click", (event) => {
    event.stopPropagation();
    navigateLightbox(1);
  });
  elements.lightbox.addEventListener("click", closeLightbox);
  elements.lightboxContent.addEventListener("click", (event) => event.stopPropagation());

  document.addEventListener("keydown", (event) => {
    if (elements.lightbox.classList.contains("is-hidden")) return;
    if (event.key === "Escape") closeLightbox();
    if (event.key === "ArrowLeft") navigateLightbox(-1);
    if (event.key === "ArrowRight") navigateLightbox(1);
  });
}

function renderAll() {
  renderVideos();
  renderPhotos();
  renderDesigns();
  renderWebsites();
}

function renderSection(key) {
  if (key === "videos") renderVideos();
  if (key === "photos") renderPhotos();
  if (key === "designs") renderDesigns();
  if (key === "websites") renderWebsites();
}

function filteredItems(key) {
  const selected = state.filters[key];
  if (selected === "all") return state.data[key];
  return state.data[key].filter((item) => item.category === selected);
}

function renderVideos() {
  const grid = document.querySelector("#videos-grid");
  replaceChildren(grid, filteredItems("videos"), (video) => {
    const card = createCard();
    const body = createElement("div", "card-body");
    body.append(createImageBlock(videoThumbnail(video.url), "Vidéo", false));

    const descriptionWrap = createElement("div", "card-meta");
    descriptionWrap.append(createText("div", "card-description", video.description));

    const meta = createElement("div", "video-meta");
    meta.append(createText("span", "tech-tag", video.category));
    if (video.platform) {
      const platform = String(video.platform).toLowerCase();
      const icon = document.createElement("img");
      icon.className = `platform-icon ${platform}`;
      icon.src = `assets/${platform}.svg`;
      icon.alt = video.platform;
      icon.loading = "lazy";
      meta.append(icon);
    }

    body.append(descriptionWrap, meta);
    card.append(body);
    makeInteractive(card, () => openLightbox("video", video));
    return card;
  });
}

function renderPhotos() {
  renderImageGallery("photos", "#photos-grid", "photo");
}

function renderDesigns() {
  renderImageGallery("designs", "#designs-grid", "design");
}

function renderImageGallery(key, selector, lightboxType) {
  const grid = document.querySelector(selector);
  replaceChildren(grid, filteredItems(key), (item) => {
    const card = createCard();
    const body = createElement("div", "card-body");
    body.append(createImageBlock(imagePath(item.image), lightboxType === "photo" ? "Photo" : "Création graphique", true));
    const descriptionWrap = createElement("div", "card-meta");
    descriptionWrap.append(createText("div", "card-description", item.description));
    const categoryWrap = createElement("div", "card-meta");
    categoryWrap.append(createText("span", "tech-tag", item.category));
    body.append(descriptionWrap, categoryWrap);
    card.append(body);
    makeInteractive(card, () => openLightbox(lightboxType, item));
    return card;
  });
}

function renderWebsites() {
  const featured = state.data.websites
    .filter((item) => String(item.highlight).toLowerCase() === "oui")
    .sort((a, b) => a.title === "GitHub" ? 1 : b.title === "GitHub" ? -1 : 0);
  replaceChildren(document.querySelector("#websites-featured"), featured, createWebsiteCard);

  const regular = filteredItems("websites")
    .filter((item) => String(item.highlight).toLowerCase() !== "oui");
  replaceChildren(document.querySelector("#websites-grid"), regular, createWebsiteCard);
}

function createWebsiteCard(project) {
  const card = createCard();
  if (project.title === "GitHub") card.classList.add("card-github");

  const body = createElement("div", "card-body");
  body.append(createImageBlock(imagePath(project.image), project.title || "Projet", false));
  const content = createElement("div", "card-content-group");
  content.append(
    createText("div", "card-title", project.title),
    createText("div", "card-description", project.description),
  );

  const tags = createElement("div", "card-meta");
  const technologies = Array.isArray(project.technologies)
    ? project.technologies
    : String(project.technologies || "").split(",").map((item) => item.trim()).filter(Boolean);
  technologies.forEach((technology) => tags.append(createText("span", "tech-tag", technology)));
  content.append(tags);
  body.append(content);
  card.append(body);

  const link = String(project.link || "").trim();
  if (link) makeInteractive(card, () => window.open(link, "_blank", "noopener,noreferrer"));
  return card;
}

function createCard() {
  return createElement("article", "card card-interactive");
}

function createImageBlock(source, alt, square) {
  const wrap = createElement("div", `card-image-container${square ? " square" : ""}`);
  const image = document.createElement("img");
  image.src = source;
  image.alt = alt;
  image.loading = "lazy";
  image.decoding = "async";
  const overlay = createElement("div", "card-hover-overlay");
  overlay.append(createText("span", "card-hover-button", "Voir"));
  wrap.append(image, overlay);
  return wrap;
}

function makeInteractive(element, callback) {
  element.tabIndex = 0;
  element.setAttribute("role", "button");
  element.addEventListener("click", callback);
  element.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      callback();
    }
  });
}

function replaceChildren(container, items, factory) {
  container.replaceChildren();
  if (!items.length) {
    container.append(createText("p", "empty-state", "Aucun élément dans cette catégorie."));
    return;
  }
  const fragment = document.createDocumentFragment();
  items.forEach((item) => fragment.append(factory(item)));
  container.append(fragment);
}

function openLightbox(type, item) {
  state.lightbox = { type, item };
  renderLightbox();
  elements.lightbox.classList.remove("is-hidden");
  document.body.style.overflow = "hidden";
  document.querySelector("#lightbox-close").focus();
}

function closeLightbox() {
  if (elements.lightbox.classList.contains("is-hidden")) return;
  elements.lightbox.classList.add("is-hidden");
  elements.lightboxContent.replaceChildren();
  document.body.style.overflow = "";
  state.lightbox = { type: null, item: null };
}

function renderLightbox() {
  const { type, item } = state.lightbox;
  elements.lightboxContent.replaceChildren();
  elements.lightboxContent.className = `lightbox-content${type === "video" ? " video" : ""}`;

  if (type === "video") {
    const frame = document.createElement("iframe");
    frame.src = embedUrl(item.url);
    frame.title = item.description || "Vidéo";
    frame.allow = "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share";
    frame.allowFullscreen = true;
    const vertical = String(item.url).includes("/shorts/") || String(item.url).includes("vimeo.com") || item.orientation === "vertical";
    frame.classList.toggle("vertical", vertical);
    elements.lightboxContent.append(frame);
    return;
  }

  const image = document.createElement("img");
  image.src = imagePath(item.image);
  image.alt = item.description || "Aperçu";
  elements.lightboxContent.append(image);
}

function navigateLightbox(direction) {
  const { type, item } = state.lightbox;
  if (!type || !item) return;
  const key = type === "video" ? "videos" : type === "design" ? "designs" : "photos";
  const items = filteredItems(key);
  if (!items.length) return;
  const current = items.findIndex((candidate) => type === "video"
    ? candidate.url === item.url
    : candidate.image === item.image);
  if (current < 0) return;
  const next = (current + direction + items.length) % items.length;
  state.lightbox.item = items[next];
  renderLightbox();
}

function imagePath(image) {
  const value = String(image || "");
  if (!value) return "";
  if (/^https?:\/\//i.test(value)) return value;
  if (value.startsWith("images/")) return value;
  return `images/${value.replace(/^\/+/, "")}`;
}

function videoThumbnail(url) {
  const youtubeId = youtubeVideoId(url);
  if (youtubeId) return `https://img.youtube.com/vi/${youtubeId}/hqdefault.jpg`;
  const vimeoId = vimeoVideoId(url);
  if (vimeoId) return `https://vumbnail.com/${vimeoId}.jpg?w=320&crop=top`;
  return "";
}

function embedUrl(url) {
  const youtubeId = youtubeVideoId(url);
  if (youtubeId) return `https://www.youtube.com/embed/${youtubeId}`;
  const vimeoId = vimeoVideoId(url);
  if (vimeoId) return `https://player.vimeo.com/video/${vimeoId}`;
  return "";
}

function youtubeVideoId(url) {
  const match = String(url || "").match(/(?:youtube\.com\/(?:watch\?v=|shorts\/|embed\/)|youtu\.be\/)([^&?/\s]{11})/i);
  return match ? match[1] : null;
}

function vimeoVideoId(url) {
  const match = String(url || "").match(/(?:vimeo\.com\/|player\.vimeo\.com\/video\/)(\d+)/i);
  return match ? match[1] : null;
}

function createElement(tag, className) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  return element;
}

function createText(tag, className, value) {
  const element = createElement(tag, className);
  element.textContent = value == null ? "" : String(value);
  return element;
}
