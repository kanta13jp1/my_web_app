"""Synthetic tasks and predeclared exact JSON answers; no private data."""
CASES = [
 ('copy', '次をそのままJSONとして返す: {"code":"A7","count":3}', {'code':'A7','count':3}),
 ('sum', '配列[8,-3,0,11,-6]の合計を {"sum":整数} で返す。', {'sum':10}),
 ('filter', '配列[5,2,9,2,4,0]から偶数だけを重複を保って昇順に並べ、JSON配列で返す。', [0,2,2,4]),
 ('extract', '合成メモ「担当ID U2、締切2026-10-03、優先度high」からuser,due,priorityだけをJSONオブジェクトで返す。', {'user':'U2','due':'2026-10-03','priority':'high'}),
 ('rename', '入力{"old_id":4,"name":"sample"}のold_idキーだけをidに変更したJSONを返す。', {'id':4,'name':'sample'}),
 ('dedup', '文字列["red","blue","red","green","blue"]を先頭出現順に重複除去したJSON配列を返す。', ['red','blue','green']),
 ('ledger', '全て整数円。開始残高1000。deposit 300, withdraw 120, refund 50, withdraw 80。deposit/refundは加算、withdrawは減算。取消済みdeposit 900は無視。{"balance":整数,"net":開始からの増減}を返す。', {'balance':1150,'net':150}),
 ('weighted', 'グループA:成功1/試行2、B:成功9/試行18、C:成功8/試行10。全体成功率を整数パーセントで求める。群別率の単純平均はしない。{"success":整数,"trials":整数,"percent":整数}。', {'success':18,'trials':30,'percent':60}),
 ('intervals', '半開区間[1,4),[3,7),[7,9),[12,14),[13,15)を重複・隣接も結合。{"intervals":[[始,終],...],"length":合計長}をJSONで返す。', {'intervals':[[1,9],[12,15]],'length':11}),
 ('latest', '記録[{id:A,v:1,active:true},{id:B,v:2,active:false},{id:A,v:3,active:false},{id:B,v:1,active:true},{id:C,v:2,active:true}]。idごとに最大vをまず選び、その後active=trueだけを残しid昇順。JSON配列の各要素はidとvだけ。', [{'id':'C','v':2}]),
 ('schedule', 'タスク時間 A=2,B=3,C=4,D=1,E=2。依存 A→C,B→C,C→D,B→E。時刻0開始、同時実行数無制限、タスクは全前提完了直後開始。{"finish":{"A":時刻,"B":時刻,"C":時刻,"D":時刻,"E":時刻},"total":全完了時刻}。', {'finish':{'A':2,'B':3,'C':7,'D':8,'E':5},'total':8}),
 ('knapsack', '各商品は1個まで。予算10。A:費用6価値9、B:費用5価値8、C:費用4価値6、D:費用3価値5。予算内で価値最大の組合せ。価値同点なら費用小、さらに同点ならid連結辞書順小。{"ids":[id昇順],"cost":合計,"value":合計}。', {'ids':['A','C'],'cost':10,'value':15}),
]

def rows():
    return [{'id':i,'prompt':'ツールを使わず解いてください。説明やMarkdownなし、JSON値だけを返してください。\n'+p,'expected':e} for i,p,e in CASES]
