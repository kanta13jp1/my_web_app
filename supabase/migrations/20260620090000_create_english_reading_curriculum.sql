-- AI大学「英語速読カリキュラム」導入 (2026-06-20)
--
-- User 要望:「英語の文章をネイティブと同じ速度で読んで理解できるようにする
-- カリキュラムを AI大学に追加。現在の実力も可視化できるようにしたい。」
--
-- 設計:
--   ネイティブ成人の黙読速度 (≈ 250-300 WPM) を到達目標に、CEFR × 目標 WPM の
--   6 段階レベル階梯で「速く・正確に読む」力を鍛える。
--   - 計測モード: 自己ペースで読了 → 内容理解クイズ → WPM / 理解率 / 実効 WPM を記録
--   - RSVP モード: 設定 WPM で単語を高速逐次提示し速度を体得
--   実力可視化: WPM 時系列・実効 WPM ゲージ (対ネイティブ 300)・CEFR 推定レベル。
--
-- 教材供給はハイブリッド:
--   - 本 migration で 6 レベル × 2 本 = 12 本の厳選スターター教材を seed
--   - ai-hub `english_reading.generate_lesson` で AI 生成教材を随時追加 (source='ai')
--
-- ==============================================
-- 1. english_reading_lessons (教材 / 公開 read)
-- ==============================================

CREATE TABLE IF NOT EXISTS english_reading_lessons (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_code  text        NOT NULL UNIQUE,
  level        int         NOT NULL,
  cefr         text        NOT NULL,
  title        text        NOT NULL,
  topic        text,
  target_wpm   int         NOT NULL,
  passage      text        NOT NULL,
  word_count   int         NOT NULL DEFAULT 0,
  questions    jsonb       NOT NULL DEFAULT '[]'::jsonb,
  source       text        NOT NULL DEFAULT 'seed',
  is_active    boolean     NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS english_reading_lessons_level_idx
  ON english_reading_lessons (level, lesson_code);
CREATE INDEX IF NOT EXISTS english_reading_lessons_source_idx
  ON english_reading_lessons (source);

ALTER TABLE english_reading_lessons ENABLE ROW LEVEL SECURITY;

-- 教材は公開コンテンツ。誰でも閲覧可 (書き込みは service role のみ = ポリシー無し)。
DROP POLICY IF EXISTS "english_reading_lessons_select_active"
  ON english_reading_lessons;
CREATE POLICY "english_reading_lessons_select_active"
  ON english_reading_lessons
  FOR SELECT USING (is_active = true);

-- ==============================================
-- 2. english_reading_attempts (実力測定ログ / user 所有)
-- ==============================================

CREATE TABLE IF NOT EXISTS english_reading_attempts (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id             uuid        REFERENCES english_reading_lessons(id) ON DELETE SET NULL,
  lesson_code           text,
  level                 int         NOT NULL DEFAULT 1,
  mode                  text        NOT NULL DEFAULT 'measure',
  word_count            int         NOT NULL DEFAULT 0,
  elapsed_ms            int         NOT NULL DEFAULT 0,
  wpm                   int         NOT NULL DEFAULT 0,
  comprehension_correct int         NOT NULL DEFAULT 0,
  comprehension_total   int         NOT NULL DEFAULT 0,
  effective_wpm         int         NOT NULL DEFAULT 0,
  created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS english_reading_attempts_user_time_idx
  ON english_reading_attempts (user_id, created_at DESC);

ALTER TABLE english_reading_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "english_reading_attempts_owner"
  ON english_reading_attempts;
CREATE POLICY "english_reading_attempts_owner"
  ON english_reading_attempts
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ==============================================
-- 3. updated_at トリガー
-- ==============================================

CREATE OR REPLACE FUNCTION update_english_reading_lessons_updated_at()
  RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_english_reading_lessons_updated_at
  ON english_reading_lessons;
CREATE TRIGGER trg_english_reading_lessons_updated_at
  BEFORE UPDATE ON english_reading_lessons
  FOR EACH ROW EXECUTE FUNCTION update_english_reading_lessons_updated_at();

-- ==============================================
-- 4. Seed: 6 レベル × 2 本 = 12 本のスターター教材
--    target_wpm は CEFR 帯の到達目標 (ネイティブ成人 ≈ 250-300 WPM)。
-- ==============================================

INSERT INTO english_reading_lessons
  (lesson_code, level, cefr, title, topic, target_wpm, passage, word_count, questions, source)
VALUES
-- ---------- Level 1 (A2 / 100 WPM) ----------
(
  'L1-01', 1, 'A2', 'A Morning Walk', 'daily life', 100,
  $p$Every morning, Mia takes a walk in the park near her house. She wakes up at six and puts on her shoes. The air is cool and the birds are singing. Mia walks for thirty minutes. She often sees other people walking their dogs. Sometimes she stops to look at the flowers. After her walk, she feels happy and ready for the day. She drinks a glass of water and eats a simple breakfast. Mia believes that a morning walk is a good way to start the day.$p$,
  87,
  $q$[
    {"q":"What time does Mia wake up?","choices":["At five","At six","At seven","At eight"],"answer_index":1,"explanation":"The text says she wakes up at six."},
    {"q":"How long does Mia walk?","choices":["Ten minutes","Twenty minutes","Thirty minutes","One hour"],"answer_index":2,"explanation":"She walks for thirty minutes."},
    {"q":"How does Mia feel after her walk?","choices":["Tired and sad","Happy and ready","Angry","Bored"],"answer_index":1,"explanation":"She feels happy and ready for the day."}
  ]$q$::jsonb,
  'seed'
),
(
  'L1-02', 1, 'A2', 'My Friend Ken', 'people', 100,
  $p$Ken is my best friend. We met at school three years ago. He is tall and he has short black hair. Ken likes to play soccer after class. On weekends, we go to the library together and read comic books. Ken is very kind. When I am sad, he listens to me and helps me feel better. He also loves animals, and he has a small brown dog named Coco. Next month, Ken and I will join the school music club. I am happy to have a friend like Ken.$p$,
  91,
  $q$[
    {"q":"Where did the writer meet Ken?","choices":["At a park","At school","At the library","At a club"],"answer_index":1,"explanation":"They met at school three years ago."},
    {"q":"What is the name of Ken's dog?","choices":["Coco","Ken","Mia","Soccer"],"answer_index":0,"explanation":"His dog is named Coco."},
    {"q":"What will they do next month?","choices":["Buy a dog","Move to a new school","Join the music club","Stop being friends"],"answer_index":2,"explanation":"They will join the school music club."}
  ]$q$::jsonb,
  'seed'
),
-- ---------- Level 2 (B1 / 150 WPM) ----------
(
  'L2-01', 2, 'B1', 'Why People Sleep', 'science', 150,
  $p$Sleep is something every person needs, but many of us do not get enough of it. While we sleep, the body does important work. It repairs muscles, stores memories, and gives the brain time to rest. Scientists say that most adults need about seven or eight hours of sleep each night. When people sleep too little, they often feel tired and find it hard to focus during the day. They may also become sick more easily. Good sleep habits can help. Going to bed at the same time each night and keeping phones away from the bed are two simple steps. By taking sleep seriously, we can think more clearly and feel better every day.$p$,
  116,
  $q$[
    {"q":"What does the body do during sleep?","choices":["Nothing useful","Repairs muscles and stores memories","Only grows taller","Burns no energy"],"answer_index":1,"explanation":"The body repairs muscles, stores memories, and rests the brain."},
    {"q":"How many hours of sleep do most adults need?","choices":["Three to four","Five to six","Seven to eight","Ten to twelve"],"answer_index":2,"explanation":"Most adults need about seven or eight hours."},
    {"q":"Which is a suggested good sleep habit?","choices":["Drink coffee at night","Keep phones away from the bed","Sleep at a different time each night","Skip sleep on busy days"],"answer_index":1,"explanation":"Keeping phones away from the bed is suggested."}
  ]$q$::jsonb,
  'seed'
),
(
  'L2-02', 2, 'B1', 'The First Day at a New Job', 'work', 150,
  $p$Sara felt nervous on her first day at the new office. She arrived early and waited quietly near the front desk. A woman named Mrs. Lee came to meet her with a warm smile. She showed Sara around the building and introduced her to the team. Everyone seemed busy, but they stopped to say hello. At lunch, two co-workers invited Sara to eat with them. They talked about their work and gave her useful advice. By the afternoon, Sara felt much more relaxed. She still had a lot to learn, but she understood that her team was ready to help. When she went home that evening, Sara was tired but glad she had taken the job.$p$,
  120,
  $q$[
    {"q":"How did Sara feel at the start of the day?","choices":["Excited","Nervous","Angry","Sleepy"],"answer_index":1,"explanation":"She felt nervous on her first day."},
    {"q":"Who showed Sara around the building?","choices":["Mrs. Lee","Sara's friend","The manager","A co-worker named Ken"],"answer_index":0,"explanation":"Mrs. Lee met her and showed her around."},
    {"q":"How did Sara feel by the end of the day?","choices":["More relaxed and glad","More nervous","Bored and tired only","Ready to quit"],"answer_index":0,"explanation":"She felt more relaxed and glad she took the job."}
  ]$q$::jsonb,
  'seed'
),
-- ---------- Level 3 (B1+ / 180 WPM) ----------
(
  'L3-01', 3, 'B1+', 'The Power of Habits', 'self-improvement', 180,
  $p$Most of what we do every day is not the result of careful decisions. Instead, it comes from habits. A habit is a small routine that the brain runs automatically, so that we do not have to think about every step. For example, when you brush your teeth or check your phone in the morning, you are following a habit. Habits are useful because they save mental energy, but they can also work against us. A bad habit, repeated daily, can slowly harm our health or waste our time. The good news is that habits can be changed. Experts suggest starting small and connecting a new habit to one you already have. If you want to read more, you might keep a book next to your bed and read one page after you turn off the alarm. Over time, these small actions add up, and the new behavior becomes natural.$p$,
  151,
  $q$[
    {"q":"According to the text, where do most daily actions come from?","choices":["Careful decisions","Habits","Other people","Random chance"],"answer_index":1,"explanation":"Most daily actions come from habits, not careful decisions."},
    {"q":"Why are habits described as useful?","choices":["They cost money","They save mental energy","They are always healthy","They require deep thought"],"answer_index":1,"explanation":"Habits save mental energy by running automatically."},
    {"q":"What method is suggested for building a new habit?","choices":["Change everything at once","Start small and link it to an existing habit","Wait for motivation","Avoid routines completely"],"answer_index":1,"explanation":"Start small and connect the new habit to one you already have."}
  ]$q$::jsonb,
  'seed'
),
(
  'L3-02', 3, 'B1+', 'How Cities Stay Cool', 'environment', 180,
  $p$On a hot summer day, a city can feel much warmer than the countryside around it. This happens because roads and buildings absorb sunlight and release heat slowly into the air. Scientists call this effect the urban heat island. As more people move into cities, the problem grows, and very high temperatures can be dangerous for older people and young children. Fortunately, city planners have found several ways to fight the heat. Planting more trees is one of the most effective. Trees provide shade and release water vapor, which cools the air nearby. Painting roofs white can also help, because light colors reflect sunlight instead of absorbing it. Some cities have even created small parks and gardens on the tops of buildings. These green spaces not only lower temperatures but also give people a pleasant place to relax. Small changes, made across an entire city, can make summers far more comfortable.$p$,
  157,
  $q$[
    {"q":"What is the urban heat island effect?","choices":["Cities being cooler than the countryside","Cities being warmer than the surrounding area","Heat only inside buildings","A type of summer storm"],"answer_index":1,"explanation":"It is when a city feels warmer than the countryside around it."},
    {"q":"Why does planting trees help?","choices":["Trees absorb heat and store it","Trees provide shade and cool the air","Trees make roads darker","Trees raise temperatures"],"answer_index":1,"explanation":"Trees give shade and release water vapor that cools the air."},
    {"q":"Why is painting roofs white useful?","choices":["White costs less","Light colors reflect sunlight","White roofs hold more heat","It looks nicer"],"answer_index":1,"explanation":"Light colors reflect sunlight instead of absorbing it."}
  ]$q$::jsonb,
  'seed'
),
-- ---------- Level 4 (B2 / 220 WPM) ----------
(
  'L4-01', 4, 'B2', 'The Hidden Cost of Free Apps', 'technology', 220,
  $p$Many of the apps we use every day cost nothing to download, yet the companies behind them earn enormous profits. This raises a simple question: if the product is free, how do these businesses make money? The answer, in most cases, is data. When you scroll through a social feed or search for a product, you generate information about your interests, your location, and your habits. Companies collect this information and use it to show you advertisements that are carefully chosen to match your behavior. In effect, your attention becomes the product being sold. Most users accept this arrangement without thinking deeply about it, partly because the benefits are immediate while the costs are hidden. A person enjoys a convenient service today and pays, indirectly, with privacy that erodes slowly over years. Critics argue that this trade is rarely transparent, because few people read the long agreements they accept with a single tap. Defenders reply that data-driven advertising keeps powerful tools free for everyone, including those who could not otherwise afford them. The debate is unlikely to end soon, but one point is clear. Being aware of how a service earns money is the first step toward using it wisely.$p$,
  207,
  $q$[
    {"q":"How do most free apps make money?","choices":["By charging hidden fees","By collecting and using user data for ads","By selling the app later","Through government support"],"answer_index":1,"explanation":"They collect user data and use it to target advertisements."},
    {"q":"What does the phrase 'your attention becomes the product' mean?","choices":["Users buy attention","Advertisers pay to reach the user's attention","The app sells phones","Attention has no value"],"answer_index":1,"explanation":"The user's attention is what is sold to advertisers."},
    {"q":"What do defenders of this model argue?","choices":["Data ads keep tools free for everyone","Users should always pay","Privacy is not important","Apps should be banned"],"answer_index":0,"explanation":"Defenders say data-driven advertising keeps tools free for all."},
    {"q":"What is the first step toward using such services wisely?","choices":["Deleting all apps","Being aware of how the service earns money","Paying for every app","Ignoring agreements"],"answer_index":1,"explanation":"Awareness of how a service earns money is the first step."}
  ]$q$::jsonb,
  'seed'
),
(
  'L4-02', 4, 'B2', 'Learning From Failure', 'psychology', 220,
  $p$We often celebrate success and quietly hide our failures, yet research suggests that failure may be one of the most valuable teachers we have. When an experiment goes wrong or a plan collapses, we are forced to examine our assumptions and ask what we missed. Success, by contrast, can be misleading. A project may succeed for reasons that have little to do with our skill, and if we never question it, we learn the wrong lessons. Psychologists who study high performers, from athletes to scientists, have noticed a common pattern. These people do not simply avoid mistakes; they analyze them carefully and adjust their methods. What separates them from others is not a lack of failure but a productive relationship with it. Of course, failure only teaches those who are willing to look at it honestly. It is far more comfortable to blame bad luck or other people than to admit a flaw in our own thinking. The discomfort is precisely the point. Growth tends to begin at the edge of our abilities, in the difficult moments when something does not work and we must figure out why. Seen this way, a setback is not the opposite of progress but often its starting point.$p$,
  210,
  $q$[
    {"q":"What is the main idea of the passage?","choices":["Failure should be avoided at all costs","Failure can be a valuable teacher","Success is never useful","Only luck matters"],"answer_index":1,"explanation":"The passage argues that failure is a valuable teacher."},
    {"q":"Why can success be misleading?","choices":["It always feels bad","It may happen for reasons unrelated to our skill","It cannot be measured","It never happens"],"answer_index":1,"explanation":"Success may occur for reasons unrelated to skill, teaching wrong lessons."},
    {"q":"What do high performers do with their mistakes?","choices":["Ignore them","Analyze them and adjust their methods","Blame others","Repeat them exactly"],"answer_index":1,"explanation":"They analyze mistakes carefully and adjust their methods."},
    {"q":"According to the writer, when does growth tend to begin?","choices":["When everything is easy","At the edge of our abilities, in difficult moments","Only after success","When we blame luck"],"answer_index":1,"explanation":"Growth tends to begin at the edge of our abilities."}
  ]$q$::jsonb,
  'seed'
),
-- ---------- Level 5 (C1 / 260 WPM) ----------
(
  'L5-01', 5, 'C1', 'The Paradox of Choice', 'economics', 260,
  $p$Common sense tells us that more choice is always better. If a market offers ten kinds of bread instead of two, surely shoppers are better off, since anyone who dislikes the extra options can simply ignore them. For decades, this assumption guided both businesses and policymakers. Yet a body of research in psychology and behavioral economics has complicated the picture in surprising ways. In one well-known study, shoppers who were offered a small selection of jam were far more likely to make a purchase than those presented with a large display of two dozen varieties. The wider array attracted attention, but it also overwhelmed people and made the decision feel risky. When every option carries the burden of a possible mistake, choosing becomes exhausting rather than liberating. This does not mean that choice is bad; freedom to choose remains essential to a good life. The point is subtler. Beyond a certain threshold, additional options yield diminishing returns and can even reduce satisfaction, because each unchosen alternative becomes a source of doubt. We wonder whether a different decision would have served us better, and that nagging question quietly erodes our contentment. Understanding this paradox allows designers, employers, and individuals to structure decisions more thoughtfully, offering enough variety to respect autonomy without drowning people in possibilities they cannot reasonably evaluate.$p$,
  227,
  $q$[
    {"q":"What common assumption does the passage challenge?","choices":["That more choice is always better","That bread is healthy","That markets are fair","That shoppers dislike jam"],"answer_index":0,"explanation":"It challenges the assumption that more choice is always better."},
    {"q":"What did the jam study find?","choices":["More varieties led to more purchases","A smaller selection led to more purchases","Nobody bought jam","Price was the only factor"],"answer_index":1,"explanation":"Shoppers with fewer options were more likely to buy."},
    {"q":"Why can too many options reduce satisfaction?","choices":["Options are expensive","Each unchosen alternative becomes a source of doubt","People love regret","Choices are illegal"],"answer_index":1,"explanation":"Unchosen alternatives create doubt that erodes contentment."},
    {"q":"What is the writer's balanced conclusion?","choices":["Choice should be removed","Offer enough variety without overwhelming people","More is always worse","Decisions do not matter"],"answer_index":1,"explanation":"Offer enough variety to respect autonomy without overwhelming people."}
  ]$q$::jsonb,
  'seed'
),
(
  'L5-02', 5, 'C1', 'Reading at the Speed of Thought', 'language learning', 260,
  $p$For learners of a second language, the gap between recognizing words and reading fluently can feel mysterious. A student may know the meaning of nearly every word on a page and still move through the text at a frustrating crawl. The obstacle is rarely vocabulary alone; it is the speed at which the brain can convert symbols into meaning without conscious effort. Native readers do not sound out each word or pause to translate. Instead, they recognize familiar chunks almost instantly, allowing attention to flow toward meaning rather than decoding. Building this kind of automaticity requires a particular sort of practice. Reading slowly and carefully, while useful for analysis, does little to increase speed. What helps more is repeated exposure to text at a pace slightly faster than feels comfortable, which gently pushes the reading system to keep up. Subvocalization, the silent inner voice that pronounces each word, also acts as a natural ceiling, since no one can speak faster than a few hundred words per minute. Skilled readers learn to rely less on that inner voice, letting the eyes lead and the meaning arrive directly. None of this happens overnight, and progress is easy to overlook from day to day. Measured across weeks, however, a reader who practices deliberately can cross the threshold from effortful decoding into something that finally feels like genuine reading.$p$,
  234,
  $q$[
    {"q":"What is identified as the main obstacle to fluent reading?","choices":["Lack of vocabulary","The speed of converting symbols into meaning","Poor eyesight","Boring texts"],"answer_index":1,"explanation":"The obstacle is the speed of converting symbols to meaning, not vocabulary alone."},
    {"q":"How do native readers process text?","choices":["They translate each word","They recognize familiar chunks almost instantly","They read aloud","They pause at every word"],"answer_index":1,"explanation":"They recognize familiar chunks instantly, freeing attention for meaning."},
    {"q":"What kind of practice helps increase reading speed?","choices":["Reading very slowly","Exposure to text slightly faster than comfortable","Only studying grammar","Avoiding reading"],"answer_index":1,"explanation":"Reading slightly faster than comfortable pushes the system to keep up."},
    {"q":"Why does subvocalization limit reading speed?","choices":["It improves memory","No one can speak faster than a few hundred words per minute","It helps the eyes","It has no effect"],"answer_index":1,"explanation":"The inner voice caps speed at speaking rate, a few hundred words per minute."}
  ]$q$::jsonb,
  'seed'
),
-- ---------- Level 6 (C2 / 300 WPM = native pace) ----------
(
  'L6-01', 6, 'C2', 'The Quiet Revolution of Standardized Time', 'history', 300,
  $p$Before the nineteenth century, time was a stubbornly local affair. Each town set its clocks by the sun, so that noon in one city might arrive several minutes earlier or later than noon in a neighbor a short distance away. For most of history this caused little trouble, because few people travelled fast enough for the discrepancy to matter. The railway changed everything. As trains began to stitch distant towns into a single network, the patchwork of local times became a genuine hazard. A timetable was meaningless if every station measured the hour differently, and collisions became a real danger when two trains shared a track on schedules that did not align. Pressed by necessity rather than philosophy, railway companies began to impose a uniform standard, and governments eventually followed, dividing the world into the broad time zones we now take for granted. What is striking, in retrospect, is how profoundly this administrative convenience reshaped human experience. People came to feel that time was an external, universal fact, ticking on independently of the sun overhead, when in truth it had been quietly redefined to suit the logic of commerce and machinery. The episode is a reminder that even our most basic categories, the ones that seem simply given by nature, often carry a hidden history of negotiation, and that the infrastructure we forget about most easily is frequently the infrastructure that has shaped us most deeply.$p$,
  240,
  $q$[
    {"q":"How was time measured before the nineteenth century?","choices":["By a single global standard","Locally, set by the sun in each town","By railway companies","By governments only"],"answer_index":1,"explanation":"Each town set its clocks by the sun, so time was local."},
    {"q":"Why did local time become a hazard?","choices":["The sun changed","Trains shared tracks on schedules that did not align","Clocks were banned","People stopped travelling"],"answer_index":1,"explanation":"Misaligned schedules made railway timetables meaningless and risked collisions."},
    {"q":"Who first imposed a uniform time standard?","choices":["Philosophers","Railway companies, then governments","Farmers","Sailors"],"answer_index":1,"explanation":"Railway companies imposed it from necessity, and governments followed."},
    {"q":"What broader point does the writer draw from the episode?","choices":["Time is purely natural","Basic categories often hide a history of negotiation","Trains were a mistake","The sun controls commerce"],"answer_index":1,"explanation":"Even basic categories carry a hidden history of negotiation."}
  ]$q$::jsonb,
  'seed'
),
(
  'L6-02', 6, 'C2', 'On the Limits of Prediction', 'science', 300,
  $p$We live in an age intoxicated by prediction. Armed with vast datasets and ever more powerful models, analysts forecast elections, markets, and the weather with a confidence that can border on the prophetic. Much of this confidence is warranted, for prediction has genuinely improved, and a meteorologist today can warn of a storm days in advance with an accuracy that would have astonished earlier generations. Yet there is a persistent temptation to forget that some systems resist forecasting not because our instruments are crude but because of their very nature. In a so-called chaotic system, tiny differences in starting conditions, too small to measure, are amplified over time until they dominate the outcome. This is not a failure of knowledge that better technology will someday repair; it is a structural feature of the world, as real and as binding as the conservation of energy. The honest forecaster, then, must hold two ideas at once: that careful analysis genuinely sharpens our expectations, and that beyond a certain horizon the future dissolves into irreducible uncertainty. Wisdom lies not in choosing between these truths but in knowing which applies to the question at hand. To demand precision where the system forbids it is a kind of arrogance, while to abandon prediction altogether, surrendering to a lazy fatalism, squanders the real understanding we have painstakingly acquired. The mature response is humbler and harder: to forecast where we can, to mark clearly where we cannot, and to resist the seductive fiction that enough data will eventually abolish surprise.$p$,
  259,
  $q$[
    {"q":"What temptation does the writer warn against?","choices":["Forgetting that some systems resist forecasting by nature","Using too little data","Trusting meteorologists","Ignoring elections"],"answer_index":0,"explanation":"He warns against forgetting that some systems resist prediction inherently."},
    {"q":"Why are chaotic systems hard to predict?","choices":["Instruments are simply too crude","Tiny differences in starting conditions get amplified over time","No one studies them","They do not exist"],"answer_index":1,"explanation":"Tiny, unmeasurable differences are amplified until they dominate the outcome."},
    {"q":"How is the unpredictability of chaos described?","choices":["A temporary problem better technology will fix","A structural feature of the world","A myth","A measurement error"],"answer_index":1,"explanation":"It is a structural feature, not a failure technology will repair."},
    {"q":"What does the writer call the 'mature response'?","choices":["Abandon prediction entirely","Demand precision everywhere","Forecast where possible and mark clearly where we cannot","Collect infinite data"],"answer_index":2,"explanation":"Forecast where we can and clearly mark where we cannot."}
  ]$q$::jsonb,
  'seed'
)
ON CONFLICT (lesson_code) DO NOTHING;

-- ==============================================
-- 5. development_achievements
-- ==============================================

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学「英語速読カリキュラム」導入',
  'User 要望「英語をネイティブと同じ速度で読んで理解できるカリキュラム + 現在の実力可視化」に対応。english_reading_lessons (公開教材 / CEFR×目標WPM 6レベル×2本 seed) と english_reading_attempts (RLS auth.uid 所有の実力測定ログ) を新設。計測モード (自己ペース読了→内容理解クイズ→WPM/理解率/実効WPM 記録) と RSVP 速読トレーナーの両UX、WPM 時系列・実効WPMゲージ・CEFR 推定レベルの実力ダッシュボードを Flutter で実装。ai-hub に english_reading.{list_lessons,get_lesson,generate_lesson,submit_attempt,ability} を追加 (教材はハイブリッド = seed + Gemini 生成)。',
  '2026-06-20'
)
ON CONFLICT DO NOTHING;
