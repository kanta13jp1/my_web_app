import copy
import unittest
from benchmark import MODEL, validate_answer


class ContractTests(unittest.TestCase):
    def setUp(self):
        self.body = {'model':MODEL,'answers':{'classification':{
            'type':'choice','choice':'food','confidence':0.5,'probabilities':{'food':0.8,'other':0.2}}}}

    def test_accepts_valid_distribution(self):
        self.assertEqual(validate_answer(self.body, ['food','other'])['choice'],'food')

    def test_rejects_fake_model(self):
        self.body['model']='fake-deterministic-v1'
        with self.assertRaises(ValueError):
            validate_answer(self.body, ['food','other'])

    def test_invalid_distributions_and_choice(self):
        for patch in [{'choice':'missing'}, {'probabilities':{'food':1}},
                      {'confidence':True}, {'confidence':float('nan')},
                      {'probabilities':{'food':0.8,'other':0.8}},
                      {'probabilities':{'food':-0.1,'other':1.1}}]:
            with self.subTest(patch=patch):
                body=copy.deepcopy(self.body)
                body['answers']['classification'].update(patch)
                with self.assertRaises(ValueError):
                    validate_answer(body,['food','other'])


if __name__ == '__main__':
    unittest.main()
