const paths={
  dashboard:'<rect x="3" y="3" width="7" height="7" rx="1.8"/><rect x="14" y="3" width="7" height="7" rx="1.8"/><rect x="3" y="14" width="7" height="7" rx="1.8"/><rect x="14" y="14" width="7" height="7" rx="1.8"/>',
  inventory:'<path d="m3 7 9-4 9 4-9 4-9-4Z"/><path d="M3 7v10l9 4 9-4V7M12 11v10"/>',
  transactions:'<path d="M4 7h15m-4-4 4 4-4 4M20 17H5m4-4-4 4 4 4"/>',
  purchases:'<path d="M3 4h2l2.1 11.1a2 2 0 0 0 2 1.6h8.6a2 2 0 0 0 2-1.6L21 8H6"/><circle cx="10" cy="20" r="1"/><circle cx="18" cy="20" r="1"/>',
  kitchen:'<path d="M4 11h16v2a8 8 0 0 1-8 8 8 8 0 0 1-8-8v-2ZM2 11h20M8 7c0-2 1.5-2 1.5-4M13 7c0-2 1.5-2 1.5-4M18 7c0-2 1.5-2 1.5-4"/>',
  plans:'<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M7 3v4M17 3v4M3 10h18M8 14h3M8 18h3M15 14h2"/>',
  suggestions:'<path d="m12 2 2.1 6.9L21 11l-6.9 2.1L12 20l-2.1-6.9L3 11l6.9-2.1L12 2ZM20 18l.6 1.4L22 20l-1.4.6L20 22l-.6-1.4L18 20l1.4-.6L20 18Z"/>',
  reports:'<path d="M4 20h16M6 17v-5M11 17V5M16 17v-8M21 17v-4"/>',
  settings:'<path d="M10.4 2h3.2l.5 2.1 1.7.7 1.9-1.1L20 6l-1.1 1.9.7 1.7 2.1.5v3.2l-2.1.5-.7 1.7L20 17.4 17.7 20l-1.9-1.1-1.7.7-.5 2.1h-3.2l-.5-2.1-1.7-.7L6.3 20 4 17.4l1.1-1.9-.7-1.7-2.1-.5v-3.2l2.1-.5.7-1.7L4 6l2.3-2.3 1.9 1.1 1.7-.7.5-2.1Z"/><circle cx="12" cy="12" r="3"/>',
  bell:'<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9ZM10 21h4"/>',
  menu:'<path d="M4 6h16M4 12h16M4 18h16"/>',
  logout:'<path d="M10 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h5M14 7l5 5-5 5M8 12h11"/>',
  plus:'<path d="M12 5v14M5 12h14"/>',
  edit:'<path d="m4 20 4.4-.9L20 7.5 16.5 4 4.9 15.6 4 20ZM14.8 5.7l3.5 3.5"/>',
  close:'<path d="M5 5l14 14M19 5 5 19"/>',
  search:'<circle cx="11" cy="11" r="7"/><path d="m16 16 5 5"/>',
  download:'<path d="M12 3v12m-4-4 4 4 4-4M4 17v3h16v-3"/>',
  alert:'<path d="m12 3 10 18H2L12 3ZM12 9v5M12 18h.01"/>',
  check:'<circle cx="12" cy="12" r="9"/><path d="m8 12 2.5 2.5L16 9"/>',
  spark:'<path d="m12 2 2.5 7.5L22 12l-7.5 2.5L12 22l-2.5-7.5L2 12l7.5-2.5L12 2Z"/>',
  food:'<path d="M3 19h18M5 19a7 7 0 0 1 14 0M12 10V8M8 6l1 2M16 6l-1 2"/>'
};
export function icon(name,extra=''){return `<svg class="svg-icon ${extra}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name]||paths.spark}</svg>`}
