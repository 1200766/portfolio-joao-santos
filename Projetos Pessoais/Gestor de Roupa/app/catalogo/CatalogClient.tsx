"use client";

/* eslint-disable @next/next/no-img-element -- The curated catalogue uses original static image paths. */

import Link from "next/link";
import {
  FormEvent,
  KeyboardEvent as ReactKeyboardEvent,
  useEffect,
  useMemo,
  useState,
} from "react";

type ClothingItem = {
  id: string;
  sortOrder: number;
  name: string;
  folderName: string;
  type: string;
  brand: string;
  size: string;
  price: string;
  condition: string;
  photos: string[];
  updatedAt?: string;
};

type SaveState = "idle" | "saving" | "saved" | "error";

type ClothingEdits = Pick<
  ClothingItem,
  "type" | "brand" | "size" | "price" | "condition"
>;

const STORAGE_KEY = "gestor-roupa:catalogo:v1";

function savedItems(
  initialItems: ClothingItem[],
  storedValue: string | null,
): ClothingItem[] {
  if (!storedValue) return initialItems;

  try {
    const edits = JSON.parse(storedValue) as Record<
      string,
      Partial<ClothingEdits>
    >;

    return initialItems.map((item) => {
      const saved = edits[item.id];
      if (!saved || typeof saved !== "object") return item;

      return {
        ...item,
        type: typeof saved.type === "string" ? saved.type : item.type,
        brand: typeof saved.brand === "string" ? saved.brand : item.brand,
        size: typeof saved.size === "string" ? saved.size : item.size,
        price: typeof saved.price === "string" ? saved.price : item.price,
        condition:
          typeof saved.condition === "string" ? saved.condition : item.condition,
      };
    });
  } catch {
    return initialItems;
  }
}

function editableFields(items: ClothingItem[]): Record<string, ClothingEdits> {
  return Object.fromEntries(
    items.map((item) => [
      item.id,
      {
        type: item.type,
        brand: item.brand,
        size: item.size,
        price: item.price,
        condition: item.condition,
      },
    ]),
  );
}

function normalize(value: string) {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
}

function initials(value: string) {
  return value
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase();
}

export default function CatalogClient({
  initialItems,
}: {
  initialItems: ClothingItem[];
}) {
  const [items, setItems] = useState(initialItems);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [draft, setDraft] = useState<ClothingItem | null>(null);
  const [activePhoto, setActivePhoto] = useState(0);
  const [query, setQuery] = useState("");
  const [typeFilter, setTypeFilter] = useState("Todos");
  const [conditionFilter, setConditionFilter] = useState("Todos");
  const [saveState, setSaveState] = useState<SaveState>("idle");

  useEffect(() => {
    const frame = window.requestAnimationFrame(() => {
      setItems(
        savedItems(initialItems, window.localStorage.getItem(STORAGE_KEY)),
      );
    });

    return () => window.cancelAnimationFrame(frame);
  }, [initialItems]);

  useEffect(() => {
    function onKeyDown(event: KeyboardEvent) {
      if (!draft) return;

      if (event.key === "Escape") {
        setSelectedId(null);
        setDraft(null);
      }

      if (
        !["INPUT", "SELECT"].includes(
          (event.target as HTMLElement)?.tagName ?? "",
        )
      ) {
        if (event.key === "ArrowRight") {
          setActivePhoto((current) =>
            Math.min(current + 1, draft.photos.length - 1),
          );
        }
        if (event.key === "ArrowLeft") {
          setActivePhoto((current) => Math.max(current - 1, 0));
        }
      }
    }

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [draft]);

  const types = useMemo(
    () =>
      Array.from(
        new Set(items.map((item) => item.type).filter(Boolean)),
      ).sort((left, right) => left.localeCompare(right, "pt")),
    [items],
  );

  const conditions = useMemo(
    () =>
      Array.from(
        new Set(items.map((item) => item.condition).filter(Boolean)),
      ).sort((left, right) => left.localeCompare(right, "pt")),
    [items],
  );

  const filteredItems = useMemo(() => {
    const search = normalize(query.trim());

    return items.filter((item) => {
      const searchable = normalize(
        [item.name, item.type, item.brand, item.size, item.condition].join(" "),
      );
      return (
        (!search || searchable.includes(search)) &&
        (typeFilter === "Todos" || item.type === typeFilter) &&
        (conditionFilter === "Todos" ||
          item.condition === conditionFilter)
      );
    });
  }, [conditionFilter, items, query, typeFilter]);

  const photoCount = useMemo(
    () => items.reduce((total, item) => total + item.photos.length, 0),
    [items],
  );

  function openItem(item: ClothingItem) {
    setSelectedId(item.id);
    setDraft({ ...item });
    setActivePhoto(0);
    setSaveState("idle");
  }

  function closeItem() {
    setSelectedId(null);
    setDraft(null);
    setSaveState("idle");
  }

  function movePhoto(direction: -1 | 1) {
    if (!draft) return;
    setActivePhoto((current) => {
      const next = current + direction;
      return Math.max(0, Math.min(next, draft.photos.length - 1));
    });
  }

  function movePhotoWithKeyboard(
    event: ReactKeyboardEvent<HTMLButtonElement>,
    index: number,
  ) {
    if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
      event.preventDefault();
      const offset = event.key === "ArrowRight" ? 1 : -1;
      const next = Math.max(
        0,
        Math.min(index + offset, (draft?.photos.length ?? 1) - 1),
      );
      setActivePhoto(next);
      document
        .querySelector<HTMLButtonElement>(`[data-photo-index="${next}"]`)
        ?.focus();
    }
  }

  function saveItem(event: FormEvent) {
    event.preventDefault();
    if (!draft) return;

    setSaveState("saving");

    try {
      const updatedItems = items.map((item) =>
        item.id === draft.id ? draft : item,
      );
      window.localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify(editableFields(updatedItems)),
      );
      setItems(updatedItems);
      setSaveState("saved");
    } catch {
      setSaveState("error");
    }
  }

  function resetItems() {
    try {
      window.localStorage.removeItem(STORAGE_KEY);
      setItems(initialItems);
      closeItem();
    } catch {
      setSaveState("error");
    }
  }

  return (
    <main className="catalog-page">
      <nav className="catalog-nav">
        <Link className="brand-mark" href="/">
          <span className="brand-dot" aria-hidden="true" />
          Segunda Volta
        </Link>
        <div className="catalog-summary">
          <span>{items.length} peças</span>
          <span>{photoCount} fotografias</span>
        </div>
      </nav>

      <header className="catalog-header">
        <div>
          <p className="eyebrow">Inventário pessoal</p>
          <h1>A tua roupa</h1>
        </div>
        <p>
          Seleciona uma peça para ver as fotografias. As alterações ficam
          apenas neste navegador.
        </p>
      </header>

      <section className="inventory-panel" aria-label="Lista de roupa">
        <div className="inventory-toolbar">
          <label className="search-field">
            <span aria-hidden="true">⌕</span>
            <span className="sr-only">Pesquisar roupa</span>
            <input
              type="search"
              placeholder="Pesquisar por peça, marca ou tamanho"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
            />
          </label>
          <div className="filters">
            <label>
              <span className="sr-only">Filtrar por tipo</span>
              <select
                value={typeFilter}
                onChange={(event) => setTypeFilter(event.target.value)}
              >
                <option>Todos</option>
                {types.map((type) => (
                  <option key={type}>{type}</option>
                ))}
              </select>
            </label>
            <label>
              <span className="sr-only">Filtrar por estado</span>
              <select
                value={conditionFilter}
                onChange={(event) => setConditionFilter(event.target.value)}
              >
                <option>Todos</option>
                {conditions.map((condition) => (
                  <option key={condition}>{condition}</option>
                ))}
              </select>
            </label>
          </div>
        </div>

        <div className="inventory-count">
          <span>
            {filteredItems.length}{" "}
            {filteredItems.length === 1 ? "resultado" : "resultados"}
          </span>
          <span className="inventory-actions">
            {(query ||
              typeFilter !== "Todos" ||
              conditionFilter !== "Todos") && (
              <button
                type="button"
                onClick={() => {
                  setQuery("");
                  setTypeFilter("Todos");
                  setConditionFilter("Todos");
                }}
              >
                Limpar filtros
              </button>
            )}
            <button type="button" onClick={resetItems}>
              Repor dados originais
            </button>
          </span>
        </div>

        <div className="inventory-table" role="table">
          <div className="inventory-head" role="row">
            <span role="columnheader">Peça</span>
            <span role="columnheader">Marca</span>
            <span role="columnheader">Tamanho</span>
            <span role="columnheader">Estado</span>
            <span role="columnheader">Preço</span>
            <span aria-hidden="true" />
          </div>

          <div className="inventory-body">
            {filteredItems.map((item, index) => (
              <button
                className="inventory-row"
                type="button"
                role="row"
                key={item.id}
                onClick={() => openItem(item)}
                aria-label={`Consultar ${item.name}`}
              >
                <span className="piece-cell" role="cell">
                  <span className="row-number">
                    {String(index + 1).padStart(2, "0")}
                  </span>
                  {item.photos[0] ? (
                    <img src={item.photos[0]} alt="" loading="lazy" />
                  ) : (
                    <span className="image-fallback" aria-hidden="true">
                      {initials(item.name)}
                    </span>
                  )}
                  <span>
                    <strong>{item.name}</strong>
                    <small>
                      {item.type || "Tipo por preencher"} · {item.photos.length}{" "}
                      fotos
                    </small>
                  </span>
                </span>
                <span role="cell" data-label="Marca">
                  {item.brand || "—"}
                </span>
                <span role="cell" data-label="Tamanho">
                  {item.size || "—"}
                </span>
                <span role="cell" data-label="Estado">
                  <span
                    className={`condition-pill ${
                      normalize(item.condition).includes("novo")
                        ? "is-new"
                        : ""
                    }`}
                  >
                    {item.condition || "Por preencher"}
                  </span>
                </span>
                <span role="cell" data-label="Preço">
                  {item.price || "Por definir"}
                </span>
                <span className="row-arrow" aria-hidden="true">
                  →
                </span>
              </button>
            ))}
          </div>
        </div>

        {filteredItems.length === 0 ? (
          <div className="empty-state">
            <span aria-hidden="true">○</span>
            <h2>Nenhuma peça encontrada</h2>
            <p>Experimenta alterar a pesquisa ou os filtros.</p>
          </div>
        ) : null}
      </section>

      {draft && selectedId ? (
        <div className="detail-layer" role="presentation">
          <button
            className="detail-backdrop"
            type="button"
            onClick={closeItem}
            aria-label="Fechar detalhes"
          />
          <aside
            className="detail-panel"
            role="dialog"
            aria-modal="true"
            aria-labelledby="detail-title"
          >
            <div className="detail-topbar">
              <div>
                <span className="detail-index">
                  PEÇA {String(draft.sortOrder).padStart(2, "0")}
                </span>
                <h2 id="detail-title">{draft.name}</h2>
              </div>
              <button
                className="close-button"
                type="button"
                onClick={closeItem}
                aria-label="Fechar detalhes"
              >
                ×
              </button>
            </div>

            <div className="detail-scroll">
              <section
                className="photo-viewer"
                aria-label={`Fotografias de ${draft.name}`}
              >
                <div className="main-photo">
                  <img
                    src={draft.photos[activePhoto]}
                    alt={`${draft.name}, fotografia ${activePhoto + 1} de ${
                      draft.photos.length
                    }`}
                  />
                  <span className="photo-counter">
                    {activePhoto + 1} / {draft.photos.length}
                  </span>
                  {draft.photos.length > 1 ? (
                    <>
                      <button
                        className="photo-arrow photo-arrow-left"
                        type="button"
                        onClick={() => movePhoto(-1)}
                        disabled={activePhoto === 0}
                        aria-label="Fotografia anterior"
                      >
                        ←
                      </button>
                      <button
                        className="photo-arrow photo-arrow-right"
                        type="button"
                        onClick={() => movePhoto(1)}
                        disabled={activePhoto === draft.photos.length - 1}
                        aria-label="Fotografia seguinte"
                      >
                        →
                      </button>
                    </>
                  ) : null}
                </div>

                <div className="photo-thumbnails" role="tablist">
                  {draft.photos.map((photo, index) => (
                    <button
                      type="button"
                      key={photo}
                      role="tab"
                      aria-selected={activePhoto === index}
                      className={activePhoto === index ? "is-active" : ""}
                      onClick={() => setActivePhoto(index)}
                      onKeyDown={(event) =>
                        movePhotoWithKeyboard(event, index)
                      }
                      data-photo-index={index}
                    >
                      <img src={photo} alt={`Fotografia ${index + 1}`} />
                    </button>
                  ))}
                </div>
              </section>

              <form className="detail-form" onSubmit={saveItem}>
                <div className="form-heading">
                  <div>
                    <span className="section-kicker">Detalhes da peça</span>
                    <h3>Informação para o anúncio</h3>
                  </div>
                  <span className="autosave-note">5 campos editáveis</span>
                </div>

                <div className="form-grid">
                  <label>
                    <span>Tipo de roupa</span>
                    <input
                      value={draft.type}
                      onChange={(event) =>
                        setDraft({ ...draft, type: event.target.value })
                      }
                      placeholder="Ex.: Top"
                    />
                  </label>
                  <label>
                    <span>Marca</span>
                    <input
                      value={draft.brand}
                      onChange={(event) =>
                        setDraft({ ...draft, brand: event.target.value })
                      }
                      placeholder="Ex.: Zara"
                    />
                  </label>
                  <label>
                    <span>Tamanho</span>
                    <input
                      value={draft.size}
                      onChange={(event) =>
                        setDraft({ ...draft, size: event.target.value })
                      }
                      placeholder="Ex.: M"
                    />
                  </label>
                  <label>
                    <span>Preço</span>
                    <div className="price-field">
                      <input
                        value={draft.price}
                        inputMode="decimal"
                        onChange={(event) =>
                          setDraft({ ...draft, price: event.target.value })
                        }
                        placeholder="0,00"
                        aria-label="Preço em euros"
                      />
                      <span>€</span>
                    </div>
                  </label>
                  <label className="full-field">
                    <span>Estado</span>
                    <input
                      list="condition-options"
                      value={draft.condition}
                      onChange={(event) =>
                        setDraft({ ...draft, condition: event.target.value })
                      }
                      placeholder="Ex.: Bom/Usado"
                    />
                    <datalist id="condition-options">
                      <option value="Novo" />
                      <option value="Como novo" />
                      <option value="Bom/Usado" />
                      <option value="Com sinais de uso" />
                    </datalist>
                  </label>
                </div>

                <div className="form-actions">
                  <p aria-live="polite">
                    {saveState === "saved" &&
                      "✓ Alterações guardadas neste navegador"}
                    {saveState === "error" &&
                      "Não foi possível guardar. Tenta novamente."}
                  </p>
                  <button
                    className="save-button"
                    type="submit"
                    disabled={saveState === "saving"}
                  >
                    {saveState === "saving"
                      ? "A guardar…"
                      : "Guardar alterações"}
                  </button>
                </div>
              </form>
            </div>
          </aside>
        </div>
      ) : null}
    </main>
  );
}
