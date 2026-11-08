import copy
import json
import unittest
from transpose import transpose, shape


def pane(identity, x, y, w, h):
    return dict(t='p', I=f'%{identity}', i=identity, x=x, y=y, w=w, h=h)


class TransposeTests(unittest.TestCase):
    def test_proportions_and_exact_round_trip_after_focus_change(self):
        doc = dict(V=2, L=dict(t='h', x=0, y=0, w=101, h=41,
                              c=[pane(1, 0, 0, 30, 41), pane(2, 31, 0, 70, 41)]))
        doc['L']['c'][0]['a'] = True
        before = json.dumps(doc)
        after, _ = transpose(before, '%1')
        changed = json.loads(after)
        self.assertEqual([c['h'] for c in changed['L']['c']], [12, 28])
        changed['L']['c'][0].pop('a')
        changed['L']['c'][1]['a'] = True
        restored, _ = transpose(json.dumps(changed), '%2', before, after)
        result = json.loads(restored)
        self.assertEqual(shape(result['L']), shape(doc['L']))
        self.assertTrue(result['L']['c'][1]['a'])

    def test_manual_resize_invalidates_cached_geometry(self):
        before = json.dumps(dict(V=2, L=dict(t='h', x=0, y=0, w=101, h=41,
                            c=[pane(1, 0, 0, 30, 41), pane(2, 31, 0, 70, 41)])))
        after, _ = transpose(before, '%1')
        resized = json.loads(after)
        resized['L']['c'][0]['h'] = 20
        resized['L']['c'][1].update(y=21, h=20)
        result, _ = transpose(json.dumps(resized), '%1', before, after)
        self.assertEqual([c['w'] for c in json.loads(result)['L']['c']], [50, 50])

    def test_local_group_preserves_other_column_and_pane_identity(self):
        left = dict(t='v', x=0, y=0, w=40, h=25,
                    c=[pane(1, 0, 0, 40, 12), pane(2, 0, 13, 40, 12)])
        right = copy.deepcopy(left)
        right.update(x=41, c=[pane(3, 41, 0, 40, 12), pane(4, 41, 13, 40, 12)])
        original = dict(V=2, L=dict(t='h', x=0, y=0, w=81, h=25, c=[left, right]))
        result, labels = transpose(json.dumps(original), '%4')
        root = json.loads(result)['L']
        self.assertEqual(root['c'][0], left)
        self.assertEqual(root['t'], 'h')
        self.assertEqual(labels, ['3', '4'])
        self.assertEqual([(c['I'], c['x'], c['y'], c['w'], c['h']) for c in root['c'][1]['c']],
                         [('%3', 41, 0, 20, 25), ('%4', 62, 0, 19, 25)])

    def test_nested_sibling_is_rejected(self):
        group = dict(t='v', c=[pane(2, 0, 0, 10, 10), pane(3, 0, 11, 10, 10)])
        doc = dict(V=2, L=dict(t='h', c=[pane(1, 0, 0, 10, 21), group]))
        with self.assertRaisesRegex(ValueError, 'nested'):
            transpose(json.dumps(doc), '%1')

    def test_insufficient_space_is_rejected(self):
        doc = dict(V=2, L=dict(t='h', w=20, h=4, x=0, y=0,
                              c=[pane(1, 0, 0, 9, 4), pane(2, 10, 0, 10, 4)]))
        with self.assertRaisesRegex(ValueError, 'space'):
            transpose(json.dumps(doc), '%2')

    def test_unknown_document_format_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'V2'):
            transpose('{"V":3,"L":{}}', '%1')


if __name__ == '__main__':
    unittest.main()
