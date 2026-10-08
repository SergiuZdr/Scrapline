// 051: shows ChatGPT's k-th full-size generated image alone, fitted to the window on white, so a
// browser screenshot can save it to disk (downloads stop at Chrome's Save dialog, and the page's
// security blocks posting to localhost). __grab(k) shows image k (0 = first >= 1000 px, -1 = the newest: the page unloads older ones), __ungrab() removes it.
window.__grab = (k) => {
  window.__ungrab && window.__ungrab();
  const imgs = Array.from(document.querySelectorAll('img')).filter(i => i.naturalWidth >= 1000 && !/attachment/i.test(i.alt || ''));
  if (k < 0) k = imgs.length + k;
  const d = document.createElement('div');
  d.id = '__grab';
  d.style.cssText = 'position:fixed;inset:0;z-index:2147483647;background:#fff;display:flex;align-items:center;justify-content:center';
  const im = document.createElement('img');
  im.src = imgs[k].src;
  im.style.cssText = 'max-width:100vw;max-height:100vh;object-fit:contain;image-rendering:auto';
  d.appendChild(im);
  document.body.appendChild(d);
  return imgs.length + ' images; showing ' + k + ' (' + imgs[k].naturalWidth + 'x' + imgs[k].naturalHeight + ')';
};
window.__ungrab = () => { const d = document.getElementById('__grab'); if (d) d.remove(); return 'removed'; };
