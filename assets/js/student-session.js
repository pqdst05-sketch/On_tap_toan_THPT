import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
const data = JSON.parse(sessionStorage.getItem('mathtex_attempt') || 'null');
if (!data?.ok) {
  location.href = 'access.html';
  throw new Error('No active attempt');
}
const cfg = window.MATHTEX_CONFIG || {};
const sb = createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY);
const $ = (id) => document.getElementById(id);
$('examTitle').textContent = data.assignment_title;
$('examMeta').textContent = `${data.student_name} · ${data.student_code} · ${data.duration_minutes} phút`;
$('studentInfo').textContent = data.student_name;
$('examFrame').src = `../${data.exam_path}`;
$('examFrame').addEventListener('load', () => {
  $('examFrame').contentWindow.postMessage({ type: 'MATHTEX_RESTORE_ANSWERS', answers }, '*');
});

let answers = data.answers || {};
let submitting = false;
let timerId = null;
let saveTimer = null;
window.addEventListener('message', (event) => {
  if (event.source !== $('examFrame').contentWindow) return;
  if (event.origin !== 'null') return;
  if (event.data?.type === 'MATHTEX_ANSWERS' && event.data.answers && typeof event.data.answers === 'object') {
    answers = event.data.answers;
    clearTimeout(saveTimer);
    saveTimer = setTimeout(saveDraft, 700);
  }
});

async function saveDraft() {
  if (submitting) return;
  const { data: result, error } = await sb.rpc('student_save_attempt', {
    p_attempt_token: data.attempt_token,
    p_answers: answers
  });
  if (error || !result?.ok) {
    $('submitMessage').textContent = result?.message || 'Chưa đồng bộ được câu trả lời; hãy kiểm tra kết nối mạng.';
  }
}

async function submit(force = false) {
  if (submitting) return;
  if (!force && !confirm('Bạn chắc chắn muốn nộp bài?')) return;
  submitting = true;
  $('submitBtn').disabled = true;
  $('submitBtn').textContent = 'Đang nộp...';
  const { data: result, error } = await sb.rpc('student_submit_attempt', {
    p_attempt_token: data.attempt_token,
    p_answers: answers
  });
  if (error || !result?.ok) {
    $('submitMessage').textContent = error?.message || result?.message || 'Chưa nộp được bài.';
    $('submitBtn').disabled = false;
    $('submitBtn').textContent = 'Nộp bài';
    submitting = false;
    return;
  }
  clearInterval(timerId);
  clearTimeout(saveTimer);
  $('submitMessage').textContent = result.status === 'expired'
    ? 'Đã hết giờ. Hệ thống đã ghi nhận bài làm.'
    : 'Đã ghi nhận nộp bài.';
  $('submitBtn').textContent = result.status === 'expired' ? 'Đã hết giờ' : 'Đã nộp bài';
  sessionStorage.removeItem('mathtex_attempt');
}
$('submitBtn').onclick = () => submit(false);

const durationDeadline = new Date(data.started_at).getTime() + Number(data.duration_minutes) * 60000;
const assignmentDeadline = data.closes_at ? new Date(data.closes_at).getTime() : durationDeadline;
const deadline = Math.min(durationDeadline, assignmentDeadline);
const tick = () => {
  const left = Math.max(0, deadline - Date.now());
  const mm = String(Math.floor(left / 60000)).padStart(2, '0');
  const ss = String(Math.floor((left % 60000) / 1000)).padStart(2, '0');
  $('timer').textContent = left > 0 ? `Còn ${mm}:${ss}` : 'Đã hết giờ';
  if (left <= 0) submit(true);
};
tick();
timerId = setInterval(tick, 1000);
