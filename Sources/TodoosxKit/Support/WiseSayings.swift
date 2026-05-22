import Foundation

public struct WiseSaying: Sendable, Equatable {
    public let quote: String
    public let author: String

    public init(quote: String, author: String) {
        self.quote = quote
        self.author = author
    }
}

public enum WiseSayings {
    public static let all: [WiseSaying] = [
        WiseSaying(
            quote: "The key is not to prioritize what's on your schedule, but to schedule your priorities.",
            author: "Stephen Covey"
        ),
        WiseSaying(
            quote: "We do not rise to the level of our goals. We fall to the level of our systems.",
            author: "James Clear"
        ),
        WiseSaying(
            quote: "Until we can manage time, we can manage nothing else.",
            author: "Peter Drucker"
        ),
        WiseSaying(
            quote: "It is not enough to be busy; so are the ants. The question is: what are we busy about?",
            author: "Henry David Thoreau"
        ),
        WiseSaying(
            quote: "Concentrate all your thoughts upon the work in hand. The sun's rays do not burn until brought to a focus.",
            author: "Alexander Graham Bell"
        ),
        WiseSaying(
            quote: "Time is the scarcest resource and unless it is managed nothing else can be managed.",
            author: "Peter Drucker"
        ),
        WiseSaying(
            quote: "You will never find time for anything. If you want time, you must make it.",
            author: "Charles Buxton"
        ),
        WiseSaying(
            quote: "Either you run the day or the day runs you.",
            author: "Jim Rohn"
        ),
        WiseSaying(
            quote: "How we spend our days is, of course, how we spend our lives.",
            author: "Annie Dillard"
        ),
        WiseSaying(
            quote: "Do the hard jobs first. The easy jobs will take care of themselves.",
            author: "Dale Carnegie"
        ),
        WiseSaying(
            quote: "Deep work is the ability to focus without distraction on a cognitively demanding task.",
            author: "Cal Newport"
        ),
        WiseSaying(
            quote: "Ordinary people think merely of spending time. Great people think of using it.",
            author: "Arthur Schopenhauer"
        ),
        WiseSaying(
            quote: "Discipline equals freedom.",
            author: "Jocko Willink"
        ),
        WiseSaying(
            quote: "What gets measured gets managed.",
            author: "Peter Drucker"
        ),
        WiseSaying(
            quote: "Begin at the beginning and go on till you come to the end; then stop.",
            author: "Lewis Carroll"
        ),
        WiseSaying(
            quote: "Waste no more time arguing about what a good man should be. Be one.",
            author: "Marcus Aurelius"
        ),
        WiseSaying(
            quote: "You have power over your mind — not outside events. Realize this, and you will find strength.",
            author: "Marcus Aurelius"
        ),
        WiseSaying(
            quote: "The impediment to action advances action. What stands in the way becomes the way.",
            author: "Marcus Aurelius"
        ),
        WiseSaying(
            quote: "Confine yourself to the present.",
            author: "Marcus Aurelius"
        ),
        WiseSaying(
            quote: "Our life is what our thoughts make it.",
            author: "Marcus Aurelius"
        ),
        WiseSaying(
            quote: "If it is not right, do not do it; if it is not true, do not say it.",
            author: "Marcus Aurelius"
        ),
        WiseSaying(
            quote: "Very little is needed to make a happy life; it is all within yourself, in your way of thinking.",
            author: "Marcus Aurelius"
        ),
        WiseSaying(
            quote: "The best revenge is to be unlike him who performed the injury.",
            author: "Marcus Aurelius"
        ),
        WiseSaying(
            quote: "Loss is nothing else but change, and change is Nature's delight.",
            author: "Marcus Aurelius"
        ),
        WiseSaying(
            quote: "The object of life is not to be on the side of the majority, but to escape finding oneself in the ranks of the insane.",
            author: "Marcus Aurelius"
        ),
        WiseSaying(
            quote: "It is not that we have a short time to live, but that we waste a lot of it.",
            author: "Seneca"
        ),
        WiseSaying(
            quote: "While we are postponing, life speeds by.",
            author: "Seneca"
        ),
        WiseSaying(
            quote: "Begin at once to live, and count each separate day as a separate life.",
            author: "Seneca"
        ),
        WiseSaying(
            quote: "We suffer more often in imagination than in reality.",
            author: "Seneca"
        ),
        WiseSaying(
            quote: "Most powerful is he who has himself in his own power.",
            author: "Seneca"
        ),
        WiseSaying(
            quote: "Difficulties strengthen the mind, as labor does the body.",
            author: "Seneca"
        ),
        WiseSaying(
            quote: "Life, if well lived, is long enough.",
            author: "Seneca"
        ),
        WiseSaying(
            quote: "If a man knows not to which port he sails, no wind is favorable.",
            author: "Seneca"
        ),
        WiseSaying(
            quote: "As long as you live, keep learning how to live.",
            author: "Seneca"
        ),
        WiseSaying(
            quote: "He suffers more than necessary, who suffers before it is necessary.",
            author: "Seneca"
        ),
        WiseSaying(
            quote: "First say to yourself what you would be; and then do what you have to do.",
            author: "Epictetus"
        ),
        WiseSaying(
            quote: "No man is free who is not master of himself.",
            author: "Epictetus"
        ),
        WiseSaying(
            quote: "Wealth consists in not having great possessions, but in having few wants.",
            author: "Epictetus"
        ),
        WiseSaying(
            quote: "It is impossible for a man to learn what he thinks he already knows.",
            author: "Epictetus"
        ),
        WiseSaying(
            quote: "Only the educated are free.",
            author: "Epictetus"
        ),
        WiseSaying(
            quote: "Well begun is half done.",
            author: "Aristotle"
        ),
        WiseSaying(
            quote: "Patience is bitter, but its fruit is sweet.",
            author: "Aristotle"
        ),
        WiseSaying(
            quote: "The roots of education are bitter, but the fruit is sweet.",
            author: "Aristotle"
        ),
        WiseSaying(
            quote: "Pleasure in the job puts perfection in the work.",
            author: "Aristotle"
        ),
        WiseSaying(
            quote: "It does not matter how slowly you go as long as you do not stop.",
            author: "Confucius"
        ),
        WiseSaying(
            quote: "The man who moves a mountain begins by carrying away small stones.",
            author: "Confucius"
        ),
        WiseSaying(
            quote: "Real knowledge is to know the extent of one's ignorance.",
            author: "Confucius"
        ),
        WiseSaying(
            quote: "Study the past if you would define the future.",
            author: "Confucius"
        ),
        WiseSaying(
            quote: "Wherever you go, go with all your heart.",
            author: "Confucius"
        ),
        WiseSaying(
            quote: "A journey of a thousand miles begins with a single step.",
            author: "Lao Tzu"
        ),
        WiseSaying(
            quote: "Nature does not hurry, yet everything is accomplished.",
            author: "Lao Tzu"
        ),
        WiseSaying(
            quote: "He who knows others is wise; he who knows himself is enlightened.",
            author: "Lao Tzu"
        ),
        WiseSaying(
            quote: "Mastering others is strength. Mastering yourself is true power.",
            author: "Lao Tzu"
        ),
        WiseSaying(
            quote: "The beginning is the most important part of the work.",
            author: "Plato"
        ),
        WiseSaying(
            quote: "An unexamined life is not worth living.",
            author: "Socrates"
        ),
        WiseSaying(
            quote: "I cannot teach anybody anything. I can only make them think.",
            author: "Socrates"
        ),
        WiseSaying(
            quote: "In the midst of chaos, there is also opportunity.",
            author: "Sun Tzu"
        ),
        WiseSaying(
            quote: "Opportunities multiply as they are seized.",
            author: "Sun Tzu"
        ),
        WiseSaying(
            quote: "Lost time is never found again.",
            author: "Benjamin Franklin"
        ),
        WiseSaying(
            quote: "By failing to prepare, you are preparing to fail.",
            author: "Benjamin Franklin"
        ),
        WiseSaying(
            quote: "Dost thou love life? Then do not squander time, for that's the stuff life is made of.",
            author: "Benjamin Franklin"
        ),
        WiseSaying(
            quote: "An investment in knowledge pays the best interest.",
            author: "Benjamin Franklin"
        ),
        WiseSaying(
            quote: "Well done is better than well said.",
            author: "Benjamin Franklin"
        ),
        WiseSaying(
            quote: "You may delay, but time will not.",
            author: "Benjamin Franklin"
        ),
        WiseSaying(
            quote: "Energy and persistence conquer all things.",
            author: "Benjamin Franklin"
        ),
        WiseSaying(
            quote: "Tell me and I forget. Teach me and I remember. Involve me and I learn.",
            author: "Benjamin Franklin"
        ),
        WiseSaying(
            quote: "Early to bed and early to rise makes a man healthy, wealthy, and wise.",
            author: "Benjamin Franklin"
        ),
        WiseSaying(
            quote: "Do what you can, with what you have, where you are.",
            author: "Theodore Roosevelt"
        ),
        WiseSaying(
            quote: "Believe you can and you're halfway there.",
            author: "Theodore Roosevelt"
        ),
        WiseSaying(
            quote: "Far and away the best prize that life offers is the chance to work hard at work worth doing.",
            author: "Theodore Roosevelt"
        ),
        WiseSaying(
            quote: "Nothing in the world is worth having or worth doing unless it means effort, pain, difficulty.",
            author: "Theodore Roosevelt"
        ),
        WiseSaying(
            quote: "Give me six hours to chop down a tree and I will spend the first four sharpening the axe.",
            author: "Abraham Lincoln"
        ),
        WiseSaying(
            quote: "You cannot escape the responsibility of tomorrow by evading it today.",
            author: "Abraham Lincoln"
        ),
        WiseSaying(
            quote: "Success is not final, failure is not fatal: It is the courage to continue that counts.",
            author: "Winston Churchill"
        ),
        WiseSaying(
            quote: "If you're going through hell, keep going.",
            author: "Winston Churchill"
        ),
        WiseSaying(
            quote: "Never give in. Never, never, never give in.",
            author: "Winston Churchill"
        ),
        WiseSaying(
            quote: "The secret of getting ahead is getting started.",
            author: "Mark Twain"
        ),
        WiseSaying(
            quote: "Twenty years from now you will be more disappointed by the things that you didn't do than by the ones you did do.",
            author: "Mark Twain"
        ),
        WiseSaying(
            quote: "Finish each day and be done with it. You have done what you could.",
            author: "Ralph Waldo Emerson"
        ),
        WiseSaying(
            quote: "What lies behind us and what lies before us are tiny matters compared to what lies within us.",
            author: "Ralph Waldo Emerson"
        ),
        WiseSaying(
            quote: "The only person you are destined to become is the person you decide to be.",
            author: "Ralph Waldo Emerson"
        ),
        WiseSaying(
            quote: "Make the most of yourself, for that is all there is of you.",
            author: "Ralph Waldo Emerson"
        ),
        WiseSaying(
            quote: "Go confidently in the direction of your dreams. Live the life you have imagined.",
            author: "Henry David Thoreau"
        ),
        WiseSaying(
            quote: "Things do not change; we change.",
            author: "Henry David Thoreau"
        ),
        WiseSaying(
            quote: "Our life is frittered away by detail. Simplify, simplify.",
            author: "Henry David Thoreau"
        ),
        WiseSaying(
            quote: "The price of anything is the amount of life you exchange for it.",
            author: "Henry David Thoreau"
        ),
        WiseSaying(
            quote: "The future depends on what you do today.",
            author: "Mahatma Gandhi"
        ),
        WiseSaying(
            quote: "Live as if you were to die tomorrow. Learn as if you were to live forever.",
            author: "Mahatma Gandhi"
        ),
        WiseSaying(
            quote: "Action expresses priorities.",
            author: "Mahatma Gandhi"
        ),
        WiseSaying(
            quote: "There is more to life than increasing its speed.",
            author: "Mahatma Gandhi"
        ),
        WiseSaying(
            quote: "Imagination is more important than knowledge.",
            author: "Albert Einstein"
        ),
        WiseSaying(
            quote: "Life is like riding a bicycle. To keep your balance, you must keep moving.",
            author: "Albert Einstein"
        ),
        WiseSaying(
            quote: "The only source of knowledge is experience.",
            author: "Albert Einstein"
        ),
        WiseSaying(
            quote: "I have no special talent. I am only passionately curious.",
            author: "Albert Einstein"
        ),
        WiseSaying(
            quote: "Your time is limited, so don't waste it living someone else's life.",
            author: "Steve Jobs"
        ),
        WiseSaying(
            quote: "The only way to do great work is to love what you do.",
            author: "Steve Jobs"
        ),
        WiseSaying(
            quote: "Innovation distinguishes between a leader and a follower.",
            author: "Steve Jobs"
        ),
        WiseSaying(
            quote: "Stay hungry, stay foolish.",
            author: "Steve Jobs"
        ),
        WiseSaying(
            quote: "Focus is about saying no.",
            author: "Steve Jobs"
        ),
        WiseSaying(
            quote: "Simple can be harder than complex.",
            author: "Steve Jobs"
        ),
        WiseSaying(
            quote: "Most people overestimate what they can do in one year and underestimate what they can do in ten years.",
            author: "Bill Gates"
        ),
        WiseSaying(
            quote: "Success is a lousy teacher. It seduces smart people into thinking they can't lose.",
            author: "Bill Gates"
        ),
        WiseSaying(
            quote: "Patience is a key element of success.",
            author: "Bill Gates"
        ),
        WiseSaying(
            quote: "The most important investment you can make is in yourself.",
            author: "Warren Buffett"
        ),
        WiseSaying(
            quote: "Risk comes from not knowing what you're doing.",
            author: "Warren Buffett"
        ),
        WiseSaying(
            quote: "It takes 20 years to build a reputation and five minutes to ruin it.",
            author: "Warren Buffett"
        ),
        WiseSaying(
            quote: "Someone is sitting in the shade today because someone planted a tree a long time ago.",
            author: "Warren Buffett"
        ),
        WiseSaying(
            quote: "The difference between successful people and really successful people is that really successful people say no to almost everything.",
            author: "Warren Buffett"
        ),
        WiseSaying(
            quote: "The big money is not in the buying and selling, but in the waiting.",
            author: "Charlie Munger"
        ),
        WiseSaying(
            quote: "Spend each day trying to be a little wiser than you were when you woke up.",
            author: "Charlie Munger"
        ),
        WiseSaying(
            quote: "Your brand is what other people say about you when you're not in the room.",
            author: "Jeff Bezos"
        ),
        WiseSaying(
            quote: "Earn with your mind, not your time.",
            author: "Naval Ravikant"
        ),
        WiseSaying(
            quote: "Focus on being productive instead of busy.",
            author: "Tim Ferriss"
        ),
        WiseSaying(
            quote: "Your mind is for having ideas, not holding them.",
            author: "David Allen"
        ),
        WiseSaying(
            quote: "You can do anything, but not everything.",
            author: "David Allen"
        ),
        WiseSaying(
            quote: "The price of success is hard work, dedication to the job at hand.",
            author: "Vince Lombardi"
        ),
        WiseSaying(
            quote: "Winners never quit and quitters never win.",
            author: "Vince Lombardi"
        ),
        WiseSaying(
            quote: "It's not whether you get knocked down; it's whether you get up.",
            author: "Vince Lombardi"
        ),
        WiseSaying(
            quote: "The man on top of the mountain didn't fall there.",
            author: "Vince Lombardi"
        ),
        WiseSaying(
            quote: "The difference between a successful person and others is not a lack of strength, not a lack of knowledge, but rather a lack of will.",
            author: "Vince Lombardi"
        ),
        WiseSaying(
            quote: "Failing to prepare is preparing to fail.",
            author: "John Wooden"
        ),
        WiseSaying(
            quote: "Don't let what you cannot do interfere with what you can do.",
            author: "John Wooden"
        ),
        WiseSaying(
            quote: "Make each day your masterpiece.",
            author: "John Wooden"
        ),
        WiseSaying(
            quote: "It's the little details that are vital. Little things make big things happen.",
            author: "John Wooden"
        ),
        WiseSaying(
            quote: "Be quick, but don't hurry.",
            author: "John Wooden"
        ),
        WiseSaying(
            quote: "If you spend too much time thinking about a thing, you'll never get it done.",
            author: "Bruce Lee"
        ),
        WiseSaying(
            quote: "Knowing is not enough, we must apply. Willing is not enough, we must do.",
            author: "Bruce Lee"
        ),
        WiseSaying(
            quote: "The successful warrior is the average man, with laser-like focus.",
            author: "Bruce Lee"
        ),
        WiseSaying(
            quote: "Don't fear failure. Not failure, but low aim, is the crime.",
            author: "Bruce Lee"
        ),
        WiseSaying(
            quote: "Be water, my friend.",
            author: "Bruce Lee"
        ),
        WiseSaying(
            quote: "I've failed over and over and over again in my life. And that is why I succeed.",
            author: "Michael Jordan"
        ),
        WiseSaying(
            quote: "Some people want it to happen, some wish it would happen, others make it happen.",
            author: "Michael Jordan"
        ),
        WiseSaying(
            quote: "I can accept failure, everyone fails at something. But I can't accept not trying.",
            author: "Michael Jordan"
        ),
        WiseSaying(
            quote: "Don't count the days; make the days count.",
            author: "Muhammad Ali"
        ),
        WiseSaying(
            quote: "He who is not courageous enough to take risks will accomplish nothing in life.",
            author: "Muhammad Ali"
        ),
        WiseSaying(
            quote: "The future belongs to those who believe in the beauty of their dreams.",
            author: "Eleanor Roosevelt"
        ),
        WiseSaying(
            quote: "Do one thing every day that scares you.",
            author: "Eleanor Roosevelt"
        ),
        WiseSaying(
            quote: "It is better to light a candle than curse the darkness.",
            author: "Eleanor Roosevelt"
        ),
        WiseSaying(
            quote: "No one can make you feel inferior without your consent.",
            author: "Eleanor Roosevelt"
        ),
        WiseSaying(
            quote: "Most of the important things in the world have been accomplished by people who have kept on trying when there seemed to be no hope at all.",
            author: "Dale Carnegie"
        ),
        WiseSaying(
            quote: "Inaction breeds doubt and fear. Action breeds confidence and courage.",
            author: "Dale Carnegie"
        ),
        WiseSaying(
            quote: "People rarely succeed unless they have fun in what they are doing.",
            author: "Dale Carnegie"
        ),
        WiseSaying(
            quote: "Whatever the mind can conceive and believe, the mind can achieve.",
            author: "Napoleon Hill"
        ),
        WiseSaying(
            quote: "Patience, persistence and perspiration make an unbeatable combination for success.",
            author: "Napoleon Hill"
        ),
        WiseSaying(
            quote: "Don't wait. The time will never be just right.",
            author: "Napoleon Hill"
        ),
        WiseSaying(
            quote: "Strength and growth come only through continuous effort and struggle.",
            author: "Napoleon Hill"
        ),
        WiseSaying(
            quote: "The path to success is to take massive, determined action.",
            author: "Tony Robbins"
        ),
        WiseSaying(
            quote: "Setting goals is the first step in turning the invisible into the visible.",
            author: "Tony Robbins"
        ),
        WiseSaying(
            quote: "It's not what we do once in a while that shapes our lives, but what we do consistently.",
            author: "Tony Robbins"
        ),
        WiseSaying(
            quote: "Successful people are simply those with successful habits.",
            author: "Brian Tracy"
        ),
        WiseSaying(
            quote: "Develop a clear vision of what you want, and you will become unstoppable.",
            author: "Brian Tracy"
        ),
        WiseSaying(
            quote: "You don't have to be great to start, but you have to start to be great.",
            author: "Zig Ziglar"
        ),
        WiseSaying(
            quote: "Lack of direction, not lack of time, is the problem. We all have twenty-four hour days.",
            author: "Zig Ziglar"
        ),
        WiseSaying(
            quote: "We become what we think about.",
            author: "Earl Nightingale"
        ),
        WiseSaying(
            quote: "Don't let the fear of the time it will take to accomplish something stand in the way of your doing it.",
            author: "Earl Nightingale"
        ),
        WiseSaying(
            quote: "Change your thoughts and you change your world.",
            author: "Norman Vincent Peale"
        ),
        WiseSaying(
            quote: "Shoot for the moon. Even if you miss, you'll land among the stars.",
            author: "Norman Vincent Peale"
        ),
        WiseSaying(
            quote: "Don't judge each day by the harvest you reap but by the seeds that you plant.",
            author: "Robert Louis Stevenson"
        ),
        WiseSaying(
            quote: "The mind is everything. What you think you become.",
            author: "Buddha"
        ),
        WiseSaying(
            quote: "No one saves us but ourselves. No one can and no one may. We ourselves must walk the path.",
            author: "Buddha"
        ),
        WiseSaying(
            quote: "Better than a thousand hollow words, is one word that brings peace.",
            author: "Buddha"
        ),
        WiseSaying(
            quote: "Happiness is not something ready made. It comes from your own actions.",
            author: "Dalai Lama"
        ),
        WiseSaying(
            quote: "When you talk, you are only repeating what you already know. But if you listen, you may learn something new.",
            author: "Dalai Lama"
        ),
        WiseSaying(
            quote: "If you think you are too small to make a difference, try sleeping with a mosquito.",
            author: "Dalai Lama"
        ),
        WiseSaying(
            quote: "The present moment is the only moment available to us, and it is the door to all moments.",
            author: "Thich Nhat Hanh"
        ),
        WiseSaying(
            quote: "People have a hard time letting go of their suffering. Out of a fear of the unknown, they prefer suffering that is familiar.",
            author: "Thich Nhat Hanh"
        ),
        WiseSaying(
            quote: "Realize deeply that the present moment is all you have.",
            author: "Eckhart Tolle"
        ),
        WiseSaying(
            quote: "Yesterday I was clever, so I wanted to change the world. Today I am wise, so I am changing myself.",
            author: "Rumi"
        ),
        WiseSaying(
            quote: "What you seek is seeking you.",
            author: "Rumi"
        ),
        WiseSaying(
            quote: "The wound is the place where the Light enters you.",
            author: "Rumi"
        ),
        WiseSaying(
            quote: "Work is love made visible.",
            author: "Khalil Gibran"
        ),
        WiseSaying(
            quote: "Out of suffering have emerged the strongest souls; the most massive characters are seared with scars.",
            author: "Khalil Gibran"
        ),
        WiseSaying(
            quote: "That which does not kill us makes us stronger.",
            author: "Friedrich Nietzsche"
        ),
        WiseSaying(
            quote: "He who has a why to live for can bear almost any how.",
            author: "Friedrich Nietzsche"
        ),
        WiseSaying(
            quote: "No price is too high to pay for the privilege of owning yourself.",
            author: "Friedrich Nietzsche"
        ),
        WiseSaying(
            quote: "Life can only be understood backwards; but it must be lived forwards.",
            author: "Søren Kierkegaard"
        ),
        WiseSaying(
            quote: "Anxiety is the dizziness of freedom.",
            author: "Søren Kierkegaard"
        ),
        WiseSaying(
            quote: "Talent hits a target no one else can hit. Genius hits a target no one else can see.",
            author: "Arthur Schopenhauer"
        ),
        WiseSaying(
            quote: "The perfect is the enemy of the good.",
            author: "Voltaire"
        ),
        WiseSaying(
            quote: "Judge a man by his questions rather than his answers.",
            author: "Voltaire"
        ),
        WiseSaying(
            quote: "We must cultivate our garden.",
            author: "Voltaire"
        ),
        WiseSaying(
            quote: "Action is eloquence.",
            author: "William Shakespeare"
        ),
        WiseSaying(
            quote: "Better three hours too soon than a minute too late.",
            author: "William Shakespeare"
        ),
        WiseSaying(
            quote: "What's done cannot be undone.",
            author: "William Shakespeare"
        ),
        WiseSaying(
            quote: "We know what we are, but know not what we may be.",
            author: "William Shakespeare"
        ),
        WiseSaying(
            quote: "Simplicity is the ultimate sophistication.",
            author: "Leonardo da Vinci"
        ),
        WiseSaying(
            quote: "Time stays long enough for those who use it.",
            author: "Leonardo da Vinci"
        ),
        WiseSaying(
            quote: "Iron rusts from disuse; water loses its purity from stagnation.",
            author: "Leonardo da Vinci"
        ),
        WiseSaying(
            quote: "The greatest danger for most of us is not that our aim is too high and we miss it, but that it is too low and we reach it.",
            author: "Michelangelo"
        ),
        WiseSaying(
            quote: "Great things are not done by impulse, but by a series of small things brought together.",
            author: "Vincent van Gogh"
        ),
        WiseSaying(
            quote: "I would rather die of passion than of boredom.",
            author: "Vincent van Gogh"
        ),
        WiseSaying(
            quote: "Inspiration exists, but it has to find you working.",
            author: "Pablo Picasso"
        ),
        WiseSaying(
            quote: "Everything you can imagine is real.",
            author: "Pablo Picasso"
        ),
        WiseSaying(
            quote: "They always say time changes things, but you actually have to change them yourself.",
            author: "Andy Warhol"
        ),
        WiseSaying(
            quote: "Genius is one percent inspiration and ninety-nine percent perspiration.",
            author: "Thomas Edison"
        ),
        WiseSaying(
            quote: "Opportunity is missed by most people because it is dressed in overalls and looks like work.",
            author: "Thomas Edison"
        ),
        WiseSaying(
            quote: "I have not failed. I've just found 10,000 ways that won't work.",
            author: "Thomas Edison"
        ),
        WiseSaying(
            quote: "There is no substitute for hard work.",
            author: "Thomas Edison"
        ),
        WiseSaying(
            quote: "Our greatest weakness lies in giving up. The most certain way to succeed is always to try just one more time.",
            author: "Thomas Edison"
        ),
        WiseSaying(
            quote: "Whether you think you can, or you think you can't — you're right.",
            author: "Henry Ford"
        ),
        WiseSaying(
            quote: "Quality means doing it right when no one is looking.",
            author: "Henry Ford"
        ),
        WiseSaying(
            quote: "If everyone is moving forward together, then success takes care of itself.",
            author: "Henry Ford"
        ),
        WiseSaying(
            quote: "Failure is simply the opportunity to begin again, this time more intelligently.",
            author: "Henry Ford"
        ),
        WiseSaying(
            quote: "Don't find fault, find a remedy.",
            author: "Henry Ford"
        ),
        WiseSaying(
            quote: "The way to get started is to quit talking and begin doing.",
            author: "Walt Disney"
        ),
        WiseSaying(
            quote: "All our dreams can come true, if we have the courage to pursue them.",
            author: "Walt Disney"
        ),
        WiseSaying(
            quote: "If you can dream it, you can do it.",
            author: "Walt Disney"
        ),
        WiseSaying(
            quote: "People who are unable to motivate themselves must be content with mediocrity, no matter how impressive their other talents.",
            author: "Andrew Carnegie"
        ),
        WiseSaying(
            quote: "As I grow older, I pay less attention to what men say. I just watch what they do.",
            author: "Andrew Carnegie"
        ),
        WiseSaying(
            quote: "Don't be afraid to give up the good to go for the great.",
            author: "John D. Rockefeller"
        ),
        WiseSaying(
            quote: "I would rather earn 1% off a 100 people's efforts than 100% of my own efforts.",
            author: "John D. Rockefeller"
        ),
        WiseSaying(
            quote: "I hated every minute of training, but I said, 'Don't quit. Suffer now and live the rest of your life as a champion.'",
            author: "Muhammad Ali"
        ),
        WiseSaying(
            quote: "What you think, you become. What you feel, you attract. What you imagine, you create.",
            author: "Buddha"
        ),
        WiseSaying(
            quote: "Alone we can do so little; together we can do so much.",
            author: "Helen Keller"
        ),
        WiseSaying(
            quote: "Optimism is the faith that leads to achievement. Nothing can be done without hope and confidence.",
            author: "Helen Keller"
        ),
        WiseSaying(
            quote: "Life is either a daring adventure or nothing at all.",
            author: "Helen Keller"
        ),
        WiseSaying(
            quote: "Keep your face to the sunshine and you cannot see a shadow.",
            author: "Helen Keller"
        ),
        WiseSaying(
            quote: "If you don't like something, change it. If you can't change it, change your attitude.",
            author: "Maya Angelou"
        ),
        WiseSaying(
            quote: "Nothing will work unless you do.",
            author: "Maya Angelou"
        ),
        WiseSaying(
            quote: "I've learned that people will forget what you said, people will forget what you did, but people will never forget how you made them feel.",
            author: "Maya Angelou"
        ),
        WiseSaying(
            quote: "Try to be a rainbow in someone's cloud.",
            author: "Maya Angelou"
        ),
        WiseSaying(
            quote: "You may not control all the events that happen to you, but you can decide not to be reduced by them.",
            author: "Maya Angelou"
        ),
        WiseSaying(
            quote: "Do the best you can until you know better. Then when you know better, do better.",
            author: "Maya Angelou"
        ),
        WiseSaying(
            quote: "We may encounter many defeats but we must not be defeated.",
            author: "Maya Angelou"
        ),
        WiseSaying(
            quote: "You are never too old to set another goal or to dream a new dream.",
            author: "C.S. Lewis"
        ),
        WiseSaying(
            quote: "Hardships often prepare ordinary people for an extraordinary destiny.",
            author: "C.S. Lewis"
        ),
        WiseSaying(
            quote: "Integrity is doing the right thing, even when no one is watching.",
            author: "C.S. Lewis"
        ),
        WiseSaying(
            quote: "It is our choices that show what we truly are, far more than our abilities.",
            author: "J.K. Rowling"
        ),
        WiseSaying(
            quote: "It does not do to dwell on dreams and forget to live.",
            author: "J.K. Rowling"
        ),
        WiseSaying(
            quote: "Happiness can be found, even in the darkest of times, if one only remembers to turn on the light.",
            author: "J.K. Rowling"
        ),
        WiseSaying(
            quote: "Life isn't about finding yourself. Life is about creating yourself.",
            author: "George Bernard Shaw"
        ),
        WiseSaying(
            quote: "Progress is impossible without change, and those who cannot change their minds cannot change anything.",
            author: "George Bernard Shaw"
        ),
        WiseSaying(
            quote: "We are made wise not by the recollection of our past, but by the responsibility for our future.",
            author: "George Bernard Shaw"
        ),
        WiseSaying(
            quote: "Be yourself; everyone else is already taken.",
            author: "Oscar Wilde"
        ),
        WiseSaying(
            quote: "To live is the rarest thing in the world. Most people exist, that is all.",
            author: "Oscar Wilde"
        ),
        WiseSaying(
            quote: "We are all in the gutter, but some of us are looking at the stars.",
            author: "Oscar Wilde"
        ),
        WiseSaying(
            quote: "No one is useless in this world who lightens the burdens of another.",
            author: "Charles Dickens"
        ),
        WiseSaying(
            quote: "Reflect upon your present blessings, of which every man has many, not on your past misfortunes, of which all men have some.",
            author: "Charles Dickens"
        ),
        WiseSaying(
            quote: "Everyone thinks of changing the world, but no one thinks of changing himself.",
            author: "Leo Tolstoy"
        ),
        WiseSaying(
            quote: "The two most powerful warriors are patience and time.",
            author: "Leo Tolstoy"
        ),
        WiseSaying(
            quote: "There is no greatness where there is not simplicity, goodness, and truth.",
            author: "Leo Tolstoy"
        ),
        WiseSaying(
            quote: "Above all, don't lie to yourself.",
            author: "Fyodor Dostoevsky"
        ),
        WiseSaying(
            quote: "Pain and suffering are always inevitable for a large intelligence and a deep heart.",
            author: "Fyodor Dostoevsky"
        ),
        WiseSaying(
            quote: "It is good to have an end to journey toward; but it is the journey that matters in the end.",
            author: "Ernest Hemingway"
        ),
        WiseSaying(
            quote: "There is nothing noble in being superior to your fellow man; true nobility is being superior to your former self.",
            author: "Ernest Hemingway"
        ),
        WiseSaying(
            quote: "For what it's worth: it's never too late to be whoever you want to be.",
            author: "F. Scott Fitzgerald"
        ),
        WiseSaying(
            quote: "Not everything that is faced can be changed, but nothing can be changed until it is faced.",
            author: "James Baldwin"
        ),
        WiseSaying(
            quote: "How wonderful it is that nobody need wait a single moment before starting to improve the world.",
            author: "Anne Frank"
        ),
        WiseSaying(
            quote: "Whoever is happy will make others happy too.",
            author: "Anne Frank"
        ),
        WiseSaying(
            quote: "I must not fear. Fear is the mind-killer.",
            author: "Frank Herbert"
        ),
        WiseSaying(
            quote: "In order to be irreplaceable, one must always be different.",
            author: "Coco Chanel"
        ),
        WiseSaying(
            quote: "Plans are worthless, but planning is everything.",
            author: "Dwight D. Eisenhower"
        ),
        WiseSaying(
            quote: "What counts is not necessarily the size of the dog in the fight — it's the size of the fight in the dog.",
            author: "Dwight D. Eisenhower"
        ),
        WiseSaying(
            quote: "An intellectual is a man who takes more words than necessary to tell more than he knows.",
            author: "Dwight D. Eisenhower"
        ),
        WiseSaying(
            quote: "Things do not happen. Things are made to happen.",
            author: "John F. Kennedy"
        ),
        WiseSaying(
            quote: "Efforts and courage are not enough without purpose and direction.",
            author: "John F. Kennedy"
        ),
        WiseSaying(
            quote: "The time to repair the roof is when the sun is shining.",
            author: "John F. Kennedy"
        ),
        WiseSaying(
            quote: "If you can't fly then run, if you can't run then walk, if you can't walk then crawl, but whatever you do you have to keep moving forward.",
            author: "Martin Luther King Jr."
        ),
        WiseSaying(
            quote: "The time is always right to do what is right.",
            author: "Martin Luther King Jr."
        ),
        WiseSaying(
            quote: "Faith is taking the first step even when you don't see the whole staircase.",
            author: "Martin Luther King Jr."
        ),
        WiseSaying(
            quote: "It always seems impossible until it's done.",
            author: "Nelson Mandela"
        ),
        WiseSaying(
            quote: "Education is the most powerful weapon which you can use to change the world.",
            author: "Nelson Mandela"
        ),
        WiseSaying(
            quote: "I learned that courage was not the absence of fear, but the triumph over it.",
            author: "Nelson Mandela"
        ),
        WiseSaying(
            quote: "The greatest glory in living lies not in never falling, but in rising every time we fall.",
            author: "Nelson Mandela"
        ),
        WiseSaying(
            quote: "Not all of us can do great things. But we can do small things with great love.",
            author: "Mother Teresa"
        ),
        WiseSaying(
            quote: "If you can't feed a hundred people, then feed just one.",
            author: "Mother Teresa"
        ),
        WiseSaying(
            quote: "Yesterday is gone. Tomorrow has not yet come. We have only today. Let us begin.",
            author: "Mother Teresa"
        ),
        WiseSaying(
            quote: "Excellence is to do a common thing in an uncommon way.",
            author: "Booker T. Washington"
        ),
        WiseSaying(
            quote: "Few things help an individual more than to place responsibility upon him, and to let him know that you trust him.",
            author: "Booker T. Washington"
        ),
        WiseSaying(
            quote: "Every great dream begins with a dreamer. Always remember, you have within you the strength, the patience, and the passion to reach for the stars to change the world.",
            author: "Harriet Tubman"
        ),
        WiseSaying(
            quote: "If there is no struggle, there is no progress.",
            author: "Frederick Douglass"
        ),
        WiseSaying(
            quote: "It is easier to build strong children than to repair broken men.",
            author: "Frederick Douglass"
        ),
        WiseSaying(
            quote: "Now is the accepted time, not tomorrow, not some more convenient season. It is today that our best work can be done.",
            author: "W.E.B. Du Bois"
        ),
        WiseSaying(
            quote: "I am not what happened to me, I am what I choose to become.",
            author: "Carl Jung"
        ),
        WiseSaying(
            quote: "Until you make the unconscious conscious, it will direct your life and you will call it fate.",
            author: "Carl Jung"
        ),
        WiseSaying(
            quote: "Everything that irritates us about others can lead us to an understanding of ourselves.",
            author: "Carl Jung"
        ),
        WiseSaying(
            quote: "Out of your vulnerabilities will come your strength.",
            author: "Sigmund Freud"
        ),
        WiseSaying(
            quote: "The greatest discovery of my generation is that human beings can alter their lives by altering their attitudes of mind.",
            author: "William James"
        ),
        WiseSaying(
            quote: "Act as if what you do makes a difference. It does.",
            author: "William James"
        ),
        WiseSaying(
            quote: "The greatest weapon against stress is our ability to choose one thought over another.",
            author: "William James"
        ),
        WiseSaying(
            quote: "Between stimulus and response there is a space. In that space is our power to choose our response. In our response lies our growth and our freedom.",
            author: "Viktor Frankl"
        ),
        WiseSaying(
            quote: "When we are no longer able to change a situation, we are challenged to change ourselves.",
            author: "Viktor Frankl"
        ),
        WiseSaying(
            quote: "Those who have a 'why' to live, can bear with almost any 'how'.",
            author: "Viktor Frankl"
        ),
        WiseSaying(
            quote: "Nothing in life is as important as you think it is, while you are thinking about it.",
            author: "Daniel Kahneman"
        ),
        WiseSaying(
            quote: "Somewhere, something incredible is waiting to be known.",
            author: "Carl Sagan"
        ),
        WiseSaying(
            quote: "Imagination will often carry us to worlds that never were, but without it we go nowhere.",
            author: "Carl Sagan"
        ),
        WiseSaying(
            quote: "I would rather have questions that can't be answered than answers that can't be questioned.",
            author: "Richard Feynman"
        ),
        WiseSaying(
            quote: "Study hard what interests you the most in the most undisciplined, irreverent and original manner possible.",
            author: "Richard Feynman"
        ),
        WiseSaying(
            quote: "The first principle is that you must not fool yourself — and you are the easiest person to fool.",
            author: "Richard Feynman"
        ),
        WiseSaying(
            quote: "Intelligence is the ability to adapt to change.",
            author: "Stephen Hawking"
        ),
        WiseSaying(
            quote: "Quiet people have the loudest minds.",
            author: "Stephen Hawking"
        ),
        WiseSaying(
            quote: "Look up at the stars and not down at your feet. Try to make sense of what you see, and wonder about what makes the universe exist.",
            author: "Stephen Hawking"
        ),
        WiseSaying(
            quote: "Be less curious about people and more curious about ideas.",
            author: "Marie Curie"
        ),
        WiseSaying(
            quote: "Nothing in life is to be feared, it is only to be understood. Now is the time to understand more, so that we may fear less.",
            author: "Marie Curie"
        ),
        WiseSaying(
            quote: "I was taught that the way of progress was neither swift nor easy.",
            author: "Marie Curie"
        ),
        WiseSaying(
            quote: "A man who dares to waste one hour of time has not discovered the value of life.",
            author: "Charles Darwin"
        ),
        WiseSaying(
            quote: "You cannot teach a man anything, you can only help him discover it within himself.",
            author: "Galileo Galilei"
        ),
        WiseSaying(
            quote: "If I have seen further it is by standing on the shoulders of giants.",
            author: "Isaac Newton"
        ),
        WiseSaying(
            quote: "The present is theirs; the future, for which I really worked, is mine.",
            author: "Nikola Tesla"
        ),
        WiseSaying(
            quote: "You never change things by fighting the existing reality. To change something, build a new model that makes the existing model obsolete.",
            author: "Buckminster Fuller"
        ),
        WiseSaying(
            quote: "Success is not the key to happiness. Happiness is the key to success.",
            author: "Albert Schweitzer"
        ),
        WiseSaying(
            quote: "Until he extends the circle of his compassion to all living things, man will not himself find peace.",
            author: "Albert Schweitzer"
        ),
        WiseSaying(
            quote: "The best way out is always through.",
            author: "Robert Frost"
        ),
        WiseSaying(
            quote: "Two roads diverged in a wood, and I — I took the one less traveled by, and that has made all the difference.",
            author: "Robert Frost"
        ),
        WiseSaying(
            quote: "Forever is composed of nows.",
            author: "Emily Dickinson"
        ),
        WiseSaying(
            quote: "Dwell in possibility.",
            author: "Emily Dickinson"
        ),
        WiseSaying(
            quote: "We grow accustomed to the Dark — when light is put away.",
            author: "Emily Dickinson"
        ),
        WiseSaying(
            quote: "Keep your face always toward the sunshine — and shadows will fall behind you.",
            author: "Walt Whitman"
        ),
        WiseSaying(
            quote: "I exist as I am, that is enough.",
            author: "Walt Whitman"
        ),
        WiseSaying(
            quote: "The talent of success is nothing more than doing what you can do well, and doing well whatever you do without thought of fame.",
            author: "Henry Wadsworth Longfellow"
        ),
        WiseSaying(
            quote: "Only those who will risk going too far can possibly find out how far one can go.",
            author: "T.S. Eliot"
        ),
        WiseSaying(
            quote: "Without ambition one starts nothing. Without work one finishes nothing.",
            author: "Ralph Waldo Emerson"
        ),
        WiseSaying(
            quote: "Always do what you are afraid to do.",
            author: "Ralph Waldo Emerson"
        ),
        WiseSaying(
            quote: "Write it on your heart that every day is the best day in the year.",
            author: "Ralph Waldo Emerson"
        ),
        WiseSaying(
            quote: "Live the life you've imagined.",
            author: "Henry David Thoreau"
        ),
        WiseSaying(
            quote: "Success usually comes to those who are too busy to be looking for it.",
            author: "Henry David Thoreau"
        ),
        WiseSaying(
            quote: "The man who does not read has no advantage over the man who cannot read.",
            author: "Mark Twain"
        ),
        WiseSaying(
            quote: "Whenever you find yourself on the side of the majority, it is time to pause and reflect.",
            author: "Mark Twain"
        ),
        WiseSaying(
            quote: "Mistakes are the portals of discovery.",
            author: "James Joyce"
        ),
        WiseSaying(
            quote: "Happiness can exist only in acceptance.",
            author: "George Orwell"
        ),
        WiseSaying(
            quote: "Experience is not what happens to you; it's what you do with what happens to you.",
            author: "Aldous Huxley"
        ),
        WiseSaying(
            quote: "The whole problem with the world is that fools and fanatics are always so certain of themselves, and wiser people so full of doubts.",
            author: "Bertrand Russell"
        ),
        WiseSaying(
            quote: "To conquer fear is the beginning of wisdom.",
            author: "Bertrand Russell"
        ),
        WiseSaying(
            quote: "The secret of joy in work is contained in one word — excellence.",
            author: "Pearl S. Buck"
        ),
        WiseSaying(
            quote: "Plan your work for today and every day, then work your plan.",
            author: "Margaret Thatcher"
        ),
        WiseSaying(
            quote: "I do not know anyone who has got to the top without hard work.",
            author: "Margaret Thatcher"
        ),
        WiseSaying(
            quote: "Most of us spend too much time on what is urgent and not enough time on what is important.",
            author: "Stephen Covey"
        ),
        WiseSaying(
            quote: "Begin with the end in mind.",
            author: "Stephen Covey"
        ),
        WiseSaying(
            quote: "Seek first to understand, then to be understood.",
            author: "Stephen Covey"
        ),
        WiseSaying(
            quote: "Sharpen the saw.",
            author: "Stephen Covey"
        ),
        WiseSaying(
            quote: "Habit is the intersection of knowledge, skill, and desire.",
            author: "Stephen Covey"
        ),
        WiseSaying(
            quote: "Efficiency is doing things right; effectiveness is doing the right things.",
            author: "Peter Drucker"
        ),
        WiseSaying(
            quote: "Plans are only good intentions unless they immediately degenerate into hard work.",
            author: "Peter Drucker"
        ),
        WiseSaying(
            quote: "Doing the right thing is more important than doing the thing right.",
            author: "Peter Drucker"
        ),
        WiseSaying(
            quote: "There is nothing so useless as doing efficiently that which should not be done at all.",
            author: "Peter Drucker"
        ),
        WiseSaying(
            quote: "Follow effective action with quiet reflection. From the quiet reflection will come even more effective action.",
            author: "Peter Drucker"
        ),
        WiseSaying(
            quote: "Every action you take is a vote for the type of person you wish to become.",
            author: "James Clear"
        ),
        WiseSaying(
            quote: "Habits are the compound interest of self-improvement.",
            author: "James Clear"
        ),
        WiseSaying(
            quote: "You should be far more concerned with your current trajectory than with your current results.",
            author: "James Clear"
        ),
        WiseSaying(
            quote: "Success is the product of daily habits — not once-in-a-lifetime transformations.",
            author: "James Clear"
        ),
        WiseSaying(
            quote: "Human beings, it seems, are at their best when immersed deeply in something challenging.",
            author: "Cal Newport"
        ),
        WiseSaying(
            quote: "Clarity about what matters provides clarity about what does not.",
            author: "Cal Newport"
        ),
        WiseSaying(
            quote: "If it isn't a clear yes, then it's a clear no.",
            author: "Greg McKeown"
        ),
        WiseSaying(
            quote: "The way of the Essentialist means living by design, not by default.",
            author: "Greg McKeown"
        ),
        WiseSaying(
            quote: "Done is better than perfect.",
            author: "Sheryl Sandberg"
        ),
        WiseSaying(
            quote: "Careers are not ladders, they're jungle gyms.",
            author: "Sheryl Sandberg"
        ),
        WiseSaying(
            quote: "What would you do if you weren't afraid?",
            author: "Sheryl Sandberg"
        ),
        WiseSaying(
            quote: "If you are not embarrassed by the first version of your product, you've launched too late.",
            author: "Reid Hoffman"
        ),
        WiseSaying(
            quote: "Software is eating the world.",
            author: "Marc Andreessen"
        ),
        WiseSaying(
            quote: "The biggest risk is not taking any risk.",
            author: "Mark Zuckerberg"
        ),
        WiseSaying(
            quote: "If you're changing the world, you're working on important things.",
            author: "Larry Page"
        ),
        WiseSaying(
            quote: "When something is important enough, you do it even if the odds are not in your favor.",
            author: "Elon Musk"
        ),
        WiseSaying(
            quote: "Persistence is very important. You should not give up unless you are forced to give up.",
            author: "Elon Musk"
        ),
        WiseSaying(
            quote: "Failure is an option here. If things are not failing, you are not innovating enough.",
            author: "Elon Musk"
        ),
        WiseSaying(
            quote: "Live in the future, then build what's missing.",
            author: "Paul Graham"
        ),
        WiseSaying(
            quote: "Make something people want.",
            author: "Paul Graham"
        ),
        WiseSaying(
            quote: "The most contrarian thing of all is not to oppose the crowd but to think for yourself.",
            author: "Peter Thiel"
        ),
        WiseSaying(
            quote: "Chase the vision, not the money; the money will end up following you.",
            author: "Tony Hsieh"
        ),
        WiseSaying(
            quote: "In times of adversity and change, we really discover who we are and what we're made of.",
            author: "Howard Schultz"
        ),
        WiseSaying(
            quote: "Business opportunities are like buses, there's always another one coming.",
            author: "Richard Branson"
        ),
        WiseSaying(
            quote: "Train people well enough so they can leave, treat them well enough so they don't want to.",
            author: "Richard Branson"
        ),
        WiseSaying(
            quote: "You don't learn to walk by following rules. You learn by doing, and by falling over.",
            author: "Richard Branson"
        ),
        WiseSaying(
            quote: "The greatest discovery of all time is that a person can change his future by merely changing his attitude.",
            author: "Oprah Winfrey"
        ),
        WiseSaying(
            quote: "Doing the best at this moment puts you in the best place for the next moment.",
            author: "Oprah Winfrey"
        ),
        WiseSaying(
            quote: "Almost everything will work again if you unplug it for a few minutes, including you.",
            author: "Anne Lamott"
        ),
        WiseSaying(
            quote: "Perfectionism is the voice of the oppressor.",
            author: "Anne Lamott"
        ),
        WiseSaying(
            quote: "Vulnerability is the birthplace of innovation, creativity and change.",
            author: "Brené Brown"
        ),
        WiseSaying(
            quote: "Daring to set boundaries is about having the courage to love ourselves, even when we risk disappointing others.",
            author: "Brené Brown"
        ),
        WiseSaying(
            quote: "Talk to yourself like you would to someone you love.",
            author: "Brené Brown"
        ),
        WiseSaying(
            quote: "People don't buy what you do; they buy why you do it.",
            author: "Simon Sinek"
        ),
        WiseSaying(
            quote: "Working hard for something we do not care about is called stress; working hard for something we love is called passion.",
            author: "Simon Sinek"
        ),
        WiseSaying(
            quote: "Leadership is not about being in charge. It is about taking care of those in your charge.",
            author: "Simon Sinek"
        ),
        WiseSaying(
            quote: "Practice isn't the thing you do once you're good. It's the thing you do that makes you good.",
            author: "Malcolm Gladwell"
        ),
        WiseSaying(
            quote: "Grit is passion and perseverance for very long-term goals.",
            author: "Angela Duckworth"
        ),
        WiseSaying(
            quote: "Becoming is better than being.",
            author: "Carol Dweck"
        ),
        WiseSaying(
            quote: "The view you adopt for yourself profoundly affects the way you lead your life.",
            author: "Carol Dweck"
        ),
        WiseSaying(
            quote: "The best moments usually occur when a person's body or mind is stretched to its limits in a voluntary effort to accomplish something difficult and worthwhile.",
            author: "Mihaly Csikszentmihalyi"
        ),
        WiseSaying(
            quote: "The obstacle in the path becomes the path.",
            author: "Ryan Holiday"
        ),
        WiseSaying(
            quote: "Be tolerant with others and strict with yourself.",
            author: "Ryan Holiday"
        ),
        WiseSaying(
            quote: "Read books are far less valuable than unread ones.",
            author: "Nassim Nicholas Taleb"
        ),
        WiseSaying(
            quote: "The mark of higher education isn't the knowledge you accumulate in your head.",
            author: "Adam Grant"
        ),
        WiseSaying(
            quote: "The secret to high performance isn't rewards and punishments, but that unseen intrinsic drive.",
            author: "Daniel Pink"
        ),
        WiseSaying(
            quote: "If you don't know where you're going, you'll end up someplace else.",
            author: "Yogi Berra"
        ),
        WiseSaying(
            quote: "It ain't over till it's over.",
            author: "Yogi Berra"
        ),
        WiseSaying(
            quote: "You can observe a lot just by watching.",
            author: "Yogi Berra"
        ),
        WiseSaying(
            quote: "You miss 100% of the shots you don't take.",
            author: "Wayne Gretzky"
        ),
        WiseSaying(
            quote: "It's hard to beat a person who never gives up.",
            author: "Babe Ruth"
        ),
        WiseSaying(
            quote: "Never let the fear of striking out keep you from playing the game.",
            author: "Babe Ruth"
        ),
        WiseSaying(
            quote: "We all have dreams. But in order to make dreams come into reality, it takes an awful lot of determination, dedication, self-discipline, and effort.",
            author: "Jesse Owens"
        ),
        WiseSaying(
            quote: "Everything negative — pressure, challenges — is all an opportunity for me to rise.",
            author: "Kobe Bryant"
        ),
        WiseSaying(
            quote: "The most important thing is to try and inspire people so that they can be great in whatever they want to do.",
            author: "Kobe Bryant"
        ),
        WiseSaying(
            quote: "Success is no accident. It is hard work, perseverance, learning, studying, sacrifice and most of all, love of what you are doing or learning to do.",
            author: "Pelé"
        ),
        WiseSaying(
            quote: "Excellence is the gradual result of always striving to do better.",
            author: "Pat Riley"
        ),
        WiseSaying(
            quote: "Do your job.",
            author: "Bill Belichick"
        ),
        WiseSaying(
            quote: "Ability is what you're capable of doing. Motivation determines what you do. Attitude determines how well you do it.",
            author: "Lou Holtz"
        ),
        WiseSaying(
            quote: "Life is 10% what happens to me and 90% of how I react to it.",
            author: "Charles R. Swindoll"
        ),
        WiseSaying(
            quote: "Feedback is the breakfast of champions.",
            author: "Ken Blanchard"
        ),
        WiseSaying(
            quote: "None of us is as smart as all of us.",
            author: "Ken Blanchard"
        ),
        WiseSaying(
            quote: "Outstanding leaders go out of their way to boost the self-esteem of their personnel.",
            author: "Sam Walton"
        ),
        WiseSaying(
            quote: "Luck is a dividend of sweat. The more you sweat, the luckier you get.",
            author: "Ray Kroc"
        ),
        WiseSaying(
            quote: "The discipline of writing something down is the first step toward making it happen.",
            author: "Lee Iacocca"
        ),
        WiseSaying(
            quote: "I never dreamed about success. I worked for it.",
            author: "Estée Lauder"
        ),
        WiseSaying(
            quote: "Don't limit yourself. Many people limit themselves to what they think they can do.",
            author: "Mary Kay Ash"
        ),
        WiseSaying(
            quote: "Don't sit down and wait for the opportunities to come. Get up and make them.",
            author: "Madam C.J. Walker"
        ),
        WiseSaying(
            quote: "Don't be intimidated by what you don't know. That can be your greatest strength.",
            author: "Sara Blakely"
        ),
        WiseSaying(
            quote: "Leadership is hard to define and good leadership even harder.",
            author: "Indra Nooyi"
        ),
        WiseSaying(
            quote: "Your level of success will rarely exceed your level of personal development.",
            author: "Hal Elrod"
        ),
        WiseSaying(
            quote: "Amateurs sit and wait for inspiration, the rest of us just get up and go to work.",
            author: "Stephen King"
        ),
        WiseSaying(
            quote: "The first move toward mastery is always inward — learning who you really are.",
            author: "Robert Greene"
        ),
        WiseSaying(
            quote: "The future belongs to those who learn more skills and combine them in creative ways.",
            author: "Robert Greene"
        ),
        WiseSaying(
            quote: "What we fear doing most is usually what we most need to do.",
            author: "Tim Ferriss"
        ),
        WiseSaying(
            quote: "Lack of time is lack of priorities.",
            author: "Tim Ferriss"
        ),
        WiseSaying(
            quote: "Read what you love until you love to read.",
            author: "Naval Ravikant"
        ),
        WiseSaying(
            quote: "If you can't decide, the answer is no.",
            author: "Naval Ravikant"
        ),
        WiseSaying(
            quote: "The most important skill for getting rich is becoming a perpetual learner.",
            author: "Naval Ravikant"
        ),
    ]

    public static func random(using generator: inout some RandomNumberGenerator) -> WiseSaying {
        all.randomElement(using: &generator) ?? all[0]
    }

    public static func random() -> WiseSaying {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }
}
