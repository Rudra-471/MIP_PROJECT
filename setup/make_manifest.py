"""Generate setup/dataset_manifest.csv (already committed - you do not need to run this).

Usage: python make_manifest.py <folder containing the clones "actualmed" and "ieee"> <output.csv>

Selection rules (deterministic, documented for reproducibility):
  * only frontal X-rays (PA / AP / AP Erect) from the ieee8023 "images" folder
  * ONE image per patient (first by file name) -> no patient leakage between train/test
  * Normal   = Actualmed "No finding" + ieee8023 "No Finding"
  * Abnormal = Actualmed "COVID-19" + an evenly spaced sample (by patient id) of
               ieee8023 images with any other finding (excluding "todo"),
               sized so both classes have the same number of images.
"""
import csv, sys, os
root = sys.argv[1]; out = sys.argv[2]
def first_per_patient(rows, key):
    seen = {}
    for x in sorted(rows, key=key):
        seen.setdefault(x['patientid'], x)
    return [seen[p] for p in sorted(seen)]
clean = lambda s: s.replace(',', ';').strip()
rows = []
a = list(csv.DictReader(open(os.path.join(root, 'actualmed/metadata.csv'))))
for finding, cls in [('No finding', 'Normal'), ('COVID-19', 'Abnormal')]:
    sel = first_per_patient([x for x in a if x['finding'] == finding], key=lambda x: x['imagename'])
    for x in sel:
        rows.append([cls, 'actualmed', x['patientid'], 'images/' + x['imagename'], finding, x['view'], 'research use only (see repository README)'])
r = list(csv.DictReader(open(os.path.join(root, 'ieee/metadata.csv'))))
xr = [x for x in r if x['modality'] == 'X-ray' and x['view'] in ('PA', 'AP', 'AP Erect') and x['folder'] == 'images']
key = lambda x: (x['patientid'].zfill(6), x['filename'])
normal = first_per_patient([x for x in xr if x['finding'] == 'No Finding'], key)
for x in normal:
    rows.append(['Normal', 'ieee8023', x['patientid'], 'images/' + x['filename'], x['finding'], x['view'], x['license'] or 'unspecified'])
abn = first_per_patient([x for x in xr if x['finding'] not in ('No Finding', 'todo')], key)
nNormal = sum(1 for x in rows if x[0] == 'Normal'); nAbn = sum(1 for x in rows if x[0] == 'Abnormal')
need = nNormal - nAbn
# evenly spaced deterministic sample over patients sorted by id
idx = [round(i * (len(abn) - 1) / (need - 1)) for i in range(need)]
for i in idx:
    x = abn[i]
    rows.append(['Abnormal', 'ieee8023', x['patientid'], 'images/' + x['filename'], x['finding'], x['view'], x['license'] or 'unspecified'])
with open(out, 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['class', 'source', 'patient_id', 'source_file', 'finding', 'view', 'license'])
    for row in rows:
        w.writerow([clean(c) for c in row])
print(len(rows), sum(1 for x in rows if x[0]=='Normal'), sum(1 for x in rows if x[0]=='Abnormal'), len(set(idx)))
