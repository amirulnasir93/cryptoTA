import { useEffect, useRef, useState } from "react";

export interface ComboOption {
  value: string;
  label: string;
  sublabel?: string;
}

// A combobox, not a native <select>: still allows typing a custom value that
// doesn't match any option (Chain/Cluster need that -- watchlist.csv already
// has values like "Ethereum/BSC/Hyperliquid" no static list would predict),
// while surfacing suggestions to reduce typos/inconsistent free text.
export function SearchableSelect({
  value,
  onChange,
  onQueryChange,
  options,
  placeholder,
  loading,
}: {
  value: string;
  onChange: (value: string) => void;
  onQueryChange?: (query: string) => void;
  options: ComboOption[];
  placeholder?: string;
  loading?: boolean;
}) {
  const [query, setQuery] = useState(value);
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setQuery(value);
  }, [value]);

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  function handleInputChange(text: string) {
    setQuery(text);
    onChange(text);
    onQueryChange?.(text);
    setOpen(true);
  }

  function handleSelect(option: ComboOption) {
    setQuery(option.label);
    onChange(option.value);
    setOpen(false);
  }

  const showDropdown = open && (options.length > 0 || loading);

  return (
    <div ref={containerRef} className="relative">
      <input
        value={query}
        onChange={(e) => handleInputChange(e.target.value)}
        onFocus={() => setOpen(true)}
        placeholder={placeholder}
        className="w-full rounded-md border border-neutral-200 bg-white px-2 py-1.5 text-sm text-neutral-900 dark:border-neutral-800 dark:bg-neutral-950 dark:text-neutral-100"
      />
      {showDropdown && (
        <div className="absolute z-10 mt-1 max-h-48 w-full overflow-y-auto rounded-md border border-neutral-200 bg-white text-sm text-neutral-900 shadow-lg dark:border-neutral-800 dark:bg-neutral-900 dark:text-neutral-100">
          {loading && <div className="px-2 py-1.5 text-neutral-400">Searching…</div>}
          {options.map((opt) => (
            <button
              key={opt.value}
              type="button"
              onClick={() => handleSelect(opt)}
              className="block w-full px-2 py-1.5 text-left text-neutral-900 hover:bg-neutral-100 dark:text-neutral-100 dark:hover:bg-neutral-800"
            >
              <div>{opt.label}</div>
              {opt.sublabel && <div className="text-xs text-neutral-400">{opt.sublabel}</div>}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
