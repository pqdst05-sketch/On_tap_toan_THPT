/* Thu thập/khôi phục câu trả lời từ đề HTML chuẩn hóa bằng data-question="Q1". */
(() => {
  function collect() {
    const out = {};
    document.querySelectorAll('[data-question]').forEach((el) => {
      const key = el.dataset.question;
      if (!key) return;
      if (el.type === 'radio') {
        if (el.checked) out[key] = el.value;
      } else if (el.type === 'checkbox') {
        if (!Array.isArray(out[key])) out[key] = [];
        if (el.checked) out[key].push(el.value);
      } else {
        out[key] = el.value;
      }
    });
    return out;
  }
  function send() {
    if (window.parent !== window) {
      window.parent.postMessage({ type: 'MATHTEX_ANSWERS', answers: collect() }, '*');
    }
  }
  function restore(answers) {
    document.querySelectorAll('[data-question]').forEach((el) => {
      const value = answers?.[el.dataset.question];
      if (el.type === 'radio') el.checked = value !== undefined && String(value) === el.value;
      else if (el.type === 'checkbox') el.checked = Array.isArray(value) && value.map(String).includes(el.value);
      else if (value !== undefined) el.value = value;
    });
    send();
  }
  window.addEventListener('message', (event) => {
    if (event.source !== window.parent) return;
    if (event.data?.type === 'MATHTEX_RESTORE_ANSWERS') restore(event.data.answers || {});
  });
  document.addEventListener('change', send);
  document.addEventListener('input', send);
  send();
})();
