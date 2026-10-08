#!/usr/bin/env python3
"""Build a local, dependency-free player for captured engine reload frames."""
import argparse
import html
import json
from pathlib import Path

from audit_weapon_motion_review import audit_capture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    args = parser.parse_args()
    base = args.capture.resolve()
    audit_path = base / "motion-review.json"
    if not audit_path.exists():
        audit_path = base / "contact-review.partial.json"
    audit = json.loads(audit_path.read_text())
    clips = {}
    for sample in audit["samples"]:
        name = sample["name"]
        if (base / (name + ".png")).is_file():
            clips.setdefault(name.split("-frame-")[0], []).append(sample)
    for frames in clips.values():
        frames.sort(key=lambda sample: sample["clip_frame"])
    status = json.loads((base / "process-result.json").read_text())
    evidence = audit_capture(base)
    (base / "recovery-audit.json").write_text(json.dumps(evidence, indent=2) + "\n")
    completion = (
        f"Screenshot evidence: {'complete' if evidence['evidence_complete'] else 'incomplete'}; "
        f"successful process exit: {'verified' if evidence['process_exit_verified'] else 'not verified'}; "
        f"requested clip scope: {'passed' if evidence['passed'] else 'not passed'}; "
        f"full nine-clip suite: {'passed' if evidence['full_suite_passed'] else 'not passed'}."
    )
    label = html.escape(status["profile"])
    command = status.get("command", [])
    renderer = status.get("renderer", audit.get("renderer"))
    if renderer is None and "--rendering-method" in command:
        renderer = command[command.index("--rendering-method") + 1]
    renderer = renderer or "unknown"
    shadows = status.get("light_shadows_disabled", audit.get("shadows_disabled"))
    provenance = html.escape(
        f"Renderer: {renderer}; light shadows disabled: "
        f"{shadows if shadows is not None else 'not recorded'}; "
        f"world geometry visible: {audit.get('world_visible', 'not recorded')}; "
        f"background materials simplified (SSAO/SSIL/MSAA disabled): "
        f"{audit.get('background_materials_simplified', False)}; "
        f"world meshes overridden: {audit.get('simplified_world_meshes', 0)}; "
        f"distant detail culling requested: {status.get('distant_details_culled', False)}; "
        f"detail meshes hidden: {audit.get('culled_detail_meshes', 'not recorded')}; "
        f"batched instances hidden: {audit.get('culled_detail_instances', 'not recorded')}.")
    document = """<!doctype html><meta charset="utf-8">
<title>Reload motion review</title>
<style>body{background:#182027;color:#eee;font:16px sans-serif;max-width:1200px;margin:24px auto}
img{max-width:100%;display:block;min-height:200px}input{width:65%}pre{white-space:pre-wrap}
.comparison{display:grid;grid-template-columns:1fr 1fr;gap:12px}
figure{margin:0}figcaption{padding:8px 0}
@media(max-width:700px){.comparison{grid-template-columns:1fr}}</style>
<p>PROFILE — Fixed 60 Hz simulation, screenshots every 6 frames (10 Hz).
Other actors hidden. Compact or culled images diagnose motion only;
they do not certify preview lighting or materials. PROVENANCE</p>
<p>Completion: COMPLETE. Sampled playback cannot prove contacts between frames,
live-input timing, locomotion or multiplayer behavior.</p>
<select id="clip"></select><button id="play">Play / pause</button>
<button id="previous" aria-label="Previous sample">Previous</button>
<button id="next" aria-label="Next sample">Next</button>
<p>Left/right arrow keys step between samples. The comparison shows the preceding
captured sample, not an interpolated frame. At clip start both images are identical.</p>
<input id="frame" type="range" min="0" value="0"><pre id="label"></pre>
<div class="comparison">
<figure><figcaption id="before-label"></figcaption><img id="before" alt="Previous captured sample"></figure>
<figure><figcaption id="current-label"></figcaption><img id="image" alt="Current captured sample"></figure>
</div>
<script>
const clips=CLIPS,select=document.querySelector('#clip'),slider=document.querySelector('#frame'),
image=document.querySelector('#image'),before=document.querySelector('#before'),
label=document.querySelector('#label');
for(const [key,frames] of Object.entries(clips)){
const o=document.createElement('option');o.value=key;o.textContent=key+' ('+frames.length+' frames)';select.append(o)}
function render(){
const frames=clips[select.value];if(!frames)return;
slider.max=frames.length-1;const s=frames[+slider.value];
const previous=frames[Math.max(0,+slider.value-1)];
before.src=previous.name+'.png';image.src=s.name+'.png';
document.querySelector('#before-label').textContent='Previous: frame '+previous.clip_frame;
document.querySelector('#current-label').textContent='Current: frame '+s.clip_frame+
' / captured gap '+(s.clip_frame-previous.clip_frame)+' simulation frames';
label.textContent=JSON.stringify(s,null,2)}
select.onchange=()=>{slider.value=0;render()};slider.oninput=render;
let playing=false;document.querySelector('#play').onclick=()=>playing=!playing;
function step(delta){playing=false;slider.value=Math.max(0,Math.min(+slider.max,+slider.value+delta));render()}
document.querySelector('#previous').onclick=()=>step(-1);
document.querySelector('#next').onclick=()=>step(1);
document.addEventListener('keydown',event=>{
if(event.target.matches('select,input,textarea')||event.altKey||event.ctrlKey||event.metaKey)return;
if(event.key==='ArrowLeft'||event.key==='ArrowRight'){
event.preventDefault();step(event.key==='ArrowLeft'?-1:1)}});
setInterval(()=>{if(playing&&select.value){slider.value=(+slider.value+1)%clips[select.value].length;render()}},100);
render();
</script>"""
    document = document.replace("PROFILE", label).replace("PROVENANCE", provenance).replace(
        "COMPLETE", html.escape(completion)
    ).replace("CLIPS", json.dumps(clips).replace("<", "\\u003c"))
    (base / "viewer.html").write_text(document)
    (base / "inventory.json").write_text(json.dumps(
        {key: len(frames) for key, frames in clips.items()}, indent=2) + "\n")
    print(base / "viewer.html")


if __name__ == "__main__":
    main()
