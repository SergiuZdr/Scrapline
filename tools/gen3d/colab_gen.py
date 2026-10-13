# 069: cell 2 as a file, for `%run -i /content/colab_gen.py` after the install cell and a restart.
# Same settings as trellis_colab.ipynb's cell 2, plus: a part that runs out of GPU memory is moved to
# /content/skip and the loop goes on, and the zip is rewritten after every model so a download at any
# moment holds everything made so far (a free runtime can vanish without warning).
import os, sys, glob, time, gc, shutil, types
os.environ['ATTN_BACKEND'] = 'xformers'
os.environ['SPCONV_ALGO'] = 'native'
os.environ['CUMM_DISABLE_JIT'] = '1'
os.environ['SPCONV_DISABLE_JIT'] = '1'
sys.path.insert(0, '/content/TRELLIS')
o3d = types.ModuleType('open3d'); o3d.geometry = types.SimpleNamespace(TriangleMesh=object)
sys.modules['open3d'] = o3d
for name in ('kaolin', 'kaolin.utils', 'kaolin.utils.testing'):
    sys.modules[name] = types.ModuleType(name)
sys.modules['kaolin.utils.testing'].check_tensor = lambda *a, **k: True
import torch
from PIL import Image
from trellis.pipelines import TrellisImageTo3DPipeline
from trellis.utils import postprocessing_utils
if 'pipeline' not in globals():
    pipeline = TrellisImageTo3DPipeline.from_pretrained('JeffreyXiang/TRELLIS-image-large')
    pipeline.cuda()
os.makedirs('/content/out', exist_ok=True)
os.makedirs('/content/skip', exist_ok=True)
paths = sorted(glob.glob('/content/*.png'))
print('inputs:', [os.path.basename(p) for p in paths])
for path in paths:
    part = os.path.splitext(os.path.basename(path))[0]
    target = '/content/out/%s.glb' % part
    if os.path.exists(target):
        continue
    t = time.time()
    failed = None
    try:
        out = pipeline.run(Image.open(path), seed=0,
                           sparse_structure_sampler_params={'steps': 12, 'cfg_strength': 7.5},
                           slat_sampler_params={'steps': 12, 'cfg_strength': 3.0},
                           formats=['gaussian', 'mesh'])
        glb = postprocessing_utils.to_glb(out['gaussian'][0], out['mesh'][0], simplify=0.95, texture_size=1024, verbose=False)
        glb.export(target)
        del out, glb
    except Exception as e:
        failed = '%s: %s' % (type(e).__name__, str(e)[:160])
    gc.collect(); torch.cuda.empty_cache()
    if failed:
        shutil.move(path, '/content/skip/')
        print('%s: FAILED (%s), moved to /content/skip' % (part, failed))
        continue
    print('%s: %.0f s, %.1f MB' % (part, time.time() - t, os.path.getsize(target) / 1e6))
    shutil.make_archive('/content/scrapline_parts', 'zip', '/content/out')
print('done:', sorted(os.listdir('/content/out')))
print('skipped:', sorted(os.listdir('/content/skip')))
