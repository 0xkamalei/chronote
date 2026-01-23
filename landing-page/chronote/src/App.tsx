import { useEffect, useState } from 'react';
import {
  Clock, Brain, Layers, TrendingUp, MessageSquare, Apple,
  CheckCircle, ArrowRight, Star, Download, Menu, X, ChevronRight,
  Zap, BarChart3, Shield, Sparkles
} from 'lucide-react';

function App() {
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const [scrollY, setScrollY] = useState(0);

  useEffect(() => {
    const handleScroll = () => setScrollY(window.scrollY);
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return (
    <div className="min-h-screen bg-[#0A0A0A] text-white antialiased">
      <Navigation isMenuOpen={isMenuOpen} setIsMenuOpen={setIsMenuOpen} scrollY={scrollY} />
      <Hero />
      <ProblemSection />
      <FeaturesSection />
      <HowItWorks />
      <Differentiator />
      <Testimonials />
      <Pricing />
      <CTASection />
      <Footer />
    </div>
  );
}

function Navigation({ isMenuOpen, setIsMenuOpen, scrollY }: {
  isMenuOpen: boolean;
  setIsMenuOpen: (v: boolean) => void;
  scrollY: number;
}) {
  return (
    <nav className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
      scrollY > 50 ? 'bg-[#0A0A0A]/90 backdrop-blur-xl border-b border-zinc-800/50' : 'bg-transparent'
    }`}>
      <div className="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
        <a href="#" className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-amber-400 to-amber-600 flex items-center justify-center">
            <Clock className="w-5 h-5 text-black" />
          </div>
          <span className="text-xl font-semibold tracking-tight">Chronote</span>
        </a>

        <div className="hidden md:flex items-center gap-8">
          <a href="#features" className="text-zinc-400 hover:text-white transition-colors text-sm">Features</a>
          <a href="#how-it-works" className="text-zinc-400 hover:text-white transition-colors text-sm">How It Works</a>
          <a href="#pricing" className="text-zinc-400 hover:text-white transition-colors text-sm">Pricing</a>
          <a href="#download" className="bg-amber-500 hover:bg-amber-400 text-black font-medium px-5 py-2.5 rounded-lg transition-all hover:shadow-lg hover:shadow-amber-500/20 text-sm">
            Download for Mac
          </a>
        </div>

        <button
          className="md:hidden text-white"
          onClick={() => setIsMenuOpen(!isMenuOpen)}
        >
          {isMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
        </button>
      </div>

      {isMenuOpen && (
        <div className="md:hidden bg-[#0A0A0A]/95 backdrop-blur-xl border-t border-zinc-800">
          <div className="px-6 py-4 flex flex-col gap-4">
            <a href="#features" className="text-zinc-400 hover:text-white transition-colors">Features</a>
            <a href="#how-it-works" className="text-zinc-400 hover:text-white transition-colors">How It Works</a>
            <a href="#pricing" className="text-zinc-400 hover:text-white transition-colors">Pricing</a>
            <a href="#download" className="bg-amber-500 hover:bg-amber-400 text-black font-medium px-5 py-3 rounded-lg text-center">
              Download for Mac
            </a>
          </div>
        </div>
      )}
    </nav>
  );
}

function Hero() {
  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden">
      {/* Video Background */}
      <div className="absolute inset-0 z-0">
        <video
          autoPlay
          muted
          loop
          playsInline
          className="w-full h-full object-cover opacity-60"
          style={{ background: '#0A0A0A' }}
        >
          <source src="./videos/hero_bg.mp4" type="video/mp4" />
        </video>
        <div className="absolute inset-0 bg-gradient-to-b from-[#0A0A0A]/40 via-transparent to-[#0A0A0A]" />
        <div className="absolute inset-0 bg-gradient-to-r from-[#0A0A0A]/60 via-transparent to-[#0A0A0A]/60" />
      </div>

      {/* Content */}
      <div className="relative z-10 max-w-6xl mx-auto px-6 pt-24 pb-12 text-center">
        <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-zinc-800/50 border border-zinc-700/50 mb-8 backdrop-blur-sm">
          <Apple className="w-4 h-4 text-amber-400" />
          <span className="text-sm text-zinc-300">Built exclusively for macOS</span>
        </div>

        <h1 className="text-5xl md:text-7xl lg:text-8xl font-bold tracking-tight leading-[0.95] mb-6">
          <span className="bg-gradient-to-b from-white to-zinc-400 bg-clip-text text-transparent">
            Chronote doesn't just
          </span>
          <br />
          <span className="bg-gradient-to-b from-white to-zinc-400 bg-clip-text text-transparent">
            track time.
          </span>
          <br />
          <span className="text-amber-400">It explains your time.</span>
        </h1>

        <p className="text-xl md:text-2xl text-zinc-400 max-w-3xl mx-auto mb-10 leading-relaxed">
          Finally understand where your day went. Chronote analyzes your behavior patterns
          and tells you WHY your time disappeared.
        </p>

        <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-16">
          <a
            href="#download"
            className="group bg-amber-500 hover:bg-amber-400 text-black font-semibold px-8 py-4 rounded-xl transition-all hover:shadow-xl hover:shadow-amber-500/30 flex items-center gap-2 text-lg"
          >
            <Download className="w-5 h-5" />
            Download for Mac
            <ChevronRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
          </a>
          <a
            href="#how-it-works"
            className="text-zinc-300 hover:text-white font-medium px-8 py-4 rounded-xl border border-zinc-700 hover:border-zinc-500 transition-all flex items-center gap-2"
          >
            See How It Works
          </a>
        </div>

        {/* App Mockup */}
        <div className="relative max-w-4xl mx-auto">
          <div className="absolute -inset-4 bg-gradient-to-r from-amber-500/20 via-amber-400/10 to-amber-500/20 rounded-2xl blur-2xl opacity-50" />
          <img
            src="./imgs/app_mockup.png"
            alt="Chronote App Interface"
            className="relative w-full rounded-xl shadow-2xl shadow-black/50 border border-zinc-800/50"
            loading="lazy"
            onError={(e) => { e.currentTarget.style.display = 'none'; }}
          />
        </div>
      </div>

      {/* Scroll Indicator */}
      <div className="absolute bottom-8 left-1/2 -translate-x-1/2 z-10">
        <div className="w-6 h-10 border-2 border-zinc-600 rounded-full flex items-start justify-center p-2">
          <div className="w-1 h-2 bg-amber-400 rounded-full animate-bounce" />
        </div>
      </div>
    </section>
  );
}

function ProblemSection() {
  const problems = [
    { icon: Clock, text: "End every day wondering where the time went" },
    { icon: Zap, text: "Feel busy but can't point to what you accomplished" },
    { icon: BarChart3, text: "Traditional time trackers show data, not insights" },
  ];

  return (
    <section className="py-24 md:py-32 bg-[#0A0A0A]">
      <div className="max-w-6xl mx-auto px-6">
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight mb-6">
            <span className="text-zinc-400">You're busy all day.</span>
            <br />
            <span className="text-white">But where did the time go?</span>
          </h2>
          <p className="text-xl text-zinc-500 max-w-2xl mx-auto">
            You've tried time trackers. They give you charts and numbers.
            But you still can't explain your day.
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-6">
          {problems.map((problem, i) => (
            <div
              key={i}
              className="p-8 rounded-2xl bg-zinc-900/50 border border-zinc-800 hover:border-zinc-700 transition-all group"
            >
              <div className="w-14 h-14 rounded-xl bg-zinc-800 flex items-center justify-center mb-6 group-hover:bg-zinc-700 transition-colors">
                <problem.icon className="w-7 h-7 text-zinc-400" />
              </div>
              <p className="text-lg text-zinc-300 leading-relaxed">{problem.text}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function FeaturesSection() {
  const features = [
    {
      icon: Brain,
      img: "./imgs/icon_behavioral.png",
      title: "Behavioral Blocks",
      description: "Groups activities into meaningful sessions like \"42 min Deep Development Session\" instead of raw app usage data.",
      highlight: "Understand context, not just apps"
    },
    {
      icon: Layers,
      img: "./imgs/icon_structure.png",
      title: "Time Structure Analysis",
      description: "See how your day breaks down: Deep Work, Fragmented Time, Passive Consumption, Context Switching.",
      highlight: "Visualize your time architecture"
    },
    {
      icon: TrendingUp,
      img: "./imgs/icon_patterns.png",
      title: "Pattern Recognition",
      description: "Identifies recurring habits across days and weeks. \"Your mornings are always fragmented.\"",
      highlight: "Spot trends you can't see"
    },
    {
      icon: MessageSquare,
      img: "./imgs/icon_narrative.png",
      title: "Narrative Explanations",
      description: "Human-readable summaries: \"You had 2 deep focus sessions today, but 17 context switches interrupted your flow.\"",
      highlight: "Stories, not spreadsheets"
    },
  ];

  return (
    <section id="features" className="py-24 md:py-32 bg-gradient-to-b from-[#0A0A0A] to-[#0F0F0F]">
      <div className="max-w-6xl mx-auto px-6">
        <div className="text-center mb-20">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-amber-500/10 border border-amber-500/20 mb-6">
            <Sparkles className="w-4 h-4 text-amber-400" />
            <span className="text-sm text-amber-400 font-medium">Intelligent Analysis</span>
          </div>
          <h2 className="text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight mb-6 text-white">
            Time tracking that thinks
          </h2>
          <p className="text-xl text-zinc-400 max-w-2xl mx-auto">
            Chronote doesn't just record what you do. It understands what you're trying to accomplish.
          </p>
        </div>

        <div className="grid md:grid-cols-2 gap-6">
          {features.map((feature, i) => (
            <div
              key={i}
              className="group p-8 rounded-2xl bg-zinc-900/30 border border-zinc-800 hover:border-amber-500/30 transition-all hover:shadow-lg hover:shadow-amber-500/5"
            >
              <div className="flex items-start gap-5">
                <div className="w-16 h-16 rounded-xl bg-gradient-to-br from-amber-500/20 to-amber-600/10 border border-amber-500/20 flex items-center justify-center flex-shrink-0 overflow-hidden">
                  <feature.icon className="w-8 h-8 text-amber-400" />
                </div>
                <div>
                  <h3 className="text-xl font-semibold text-white mb-2">{feature.title}</h3>
                  <p className="text-zinc-400 leading-relaxed mb-3">{feature.description}</p>
                  <span className="inline-flex items-center text-sm text-amber-400 font-medium">
                    {feature.highlight}
                    <ArrowRight className="w-4 h-4 ml-1 group-hover:translate-x-1 transition-transform" />
                  </span>
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* Mac Native Feature */}
        <div className="mt-12 p-8 rounded-2xl bg-gradient-to-r from-zinc-900 to-zinc-900/50 border border-zinc-800">
          <div className="flex flex-col md:flex-row items-center gap-8">
            <div className="flex-shrink-0">
              <div className="w-20 h-20 rounded-2xl bg-gradient-to-br from-zinc-700 to-zinc-800 flex items-center justify-center">
                <Apple className="w-10 h-10 text-white" />
              </div>
            </div>
            <div>
              <h3 className="text-2xl font-semibold text-white mb-2">Built for Mac. Privacy First.</h3>
              <p className="text-zinc-400 leading-relaxed">
                Native macOS app with beautiful menu bar integration. All data stays on your Mac -
                no cloud uploads, no subscriptions, no tracking. Your productivity data belongs to you.
              </p>
            </div>
            <div className="flex items-center gap-3 flex-shrink-0">
              <div className="flex items-center gap-2 px-4 py-2 rounded-lg bg-emerald-500/10 border border-emerald-500/20">
                <Shield className="w-5 h-5 text-emerald-400" />
                <span className="text-emerald-400 text-sm font-medium">100% Local</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function HowItWorks() {
  const steps = [
    {
      step: "01",
      title: "Install & Run",
      description: "Download Chronote and let it run quietly in your menu bar. No setup, no configuration."
    },
    {
      step: "02",
      title: "Work Naturally",
      description: "Just do your work. Chronote silently observes and understands your behavioral patterns."
    },
    {
      step: "03",
      title: "Understand Your Time",
      description: "Get daily insights that explain where your time went and what patterns are forming."
    }
  ];

  return (
    <section id="how-it-works" className="py-24 md:py-32 bg-[#0F0F0F]">
      <div className="max-w-6xl mx-auto px-6">
        <div className="text-center mb-20">
          <h2 className="text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight mb-6 text-white">
            Three steps to clarity
          </h2>
          <p className="text-xl text-zinc-400 max-w-2xl mx-auto">
            No complex setup. No manual time entries. Just install and gain insights.
          </p>
        </div>

        <div className="grid md:grid-cols-3 gap-8 relative">
          {/* Connecting Line */}
          <div className="hidden md:block absolute top-16 left-[20%] right-[20%] h-0.5 bg-gradient-to-r from-amber-500/50 via-amber-400/30 to-amber-500/50" />

          {steps.map((step, i) => (
            <div key={i} className="relative text-center">
              <div className="w-32 h-32 mx-auto mb-8 rounded-full bg-gradient-to-br from-amber-500/20 to-amber-600/5 border border-amber-500/20 flex items-center justify-center relative z-10 bg-[#0F0F0F]">
                <span className="text-4xl font-bold text-amber-400">{step.step}</span>
              </div>
              <h3 className="text-2xl font-semibold text-white mb-3">{step.title}</h3>
              <p className="text-zinc-400 leading-relaxed">{step.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function Differentiator() {
  const traditional = [
    "Shows you raw app usage time",
    "Pie charts of categories",
    "Requires manual time entries",
    "Data visualization without context",
    "You interpret the data yourself"
  ];

  const chronote = [
    "Groups into behavioral sessions",
    "Explains WHY time disappeared",
    "Fully automatic tracking",
    "Narrative insights with context",
    "AI explains patterns for you"
  ];

  return (
    <section className="py-24 md:py-32 bg-gradient-to-b from-[#0F0F0F] to-[#0A0A0A]">
      <div className="max-w-6xl mx-auto px-6">
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight mb-6 text-white">
            Not another time tracker
          </h2>
          <p className="text-xl text-zinc-400 max-w-2xl mx-auto">
            Traditional tools give you data. Chronote gives you understanding.
          </p>
        </div>

        <div className="grid md:grid-cols-2 gap-8">
          {/* Traditional */}
          <div className="p-8 rounded-2xl bg-zinc-900/30 border border-zinc-800">
            <div className="flex items-center gap-3 mb-8">
              <div className="w-10 h-10 rounded-lg bg-zinc-800 flex items-center justify-center">
                <BarChart3 className="w-5 h-5 text-zinc-500" />
              </div>
              <h3 className="text-xl font-semibold text-zinc-400">Traditional Trackers</h3>
            </div>
            <ul className="space-y-4">
              {traditional.map((item, i) => (
                <li key={i} className="flex items-start gap-3 text-zinc-500">
                  <div className="w-5 h-5 rounded-full bg-zinc-800 flex-shrink-0 mt-0.5" />
                  <span>{item}</span>
                </li>
              ))}
            </ul>
          </div>

          {/* Chronote */}
          <div className="p-8 rounded-2xl bg-gradient-to-br from-amber-500/10 to-amber-600/5 border border-amber-500/20">
            <div className="flex items-center gap-3 mb-8">
              <div className="w-10 h-10 rounded-lg bg-amber-500 flex items-center justify-center">
                <Brain className="w-5 h-5 text-black" />
              </div>
              <h3 className="text-xl font-semibold text-white">Chronote</h3>
            </div>
            <ul className="space-y-4">
              {chronote.map((item, i) => (
                <li key={i} className="flex items-start gap-3 text-zinc-200">
                  <CheckCircle className="w-5 h-5 text-amber-400 flex-shrink-0 mt-0.5" />
                  <span>{item}</span>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </section>
  );
}

function Testimonials() {
  const testimonials = [
    {
      quote: "I finally understand why my days feel fragmented. Chronote showed me I context-switch 40+ times daily. Now I batch my work and gained 2 hours of deep focus.",
      author: "Sarah Chen",
      role: "Senior Developer @ Stripe",
      avatar: "SC"
    },
    {
      quote: "Other trackers told me I worked 10 hours. Chronote told me only 3 of those were focused work. That insight changed how I structure my entire day.",
      author: "Marcus Webb",
      role: "Freelance Designer",
      avatar: "MW"
    },
    {
      quote: "The weekly patterns feature is gold. I discovered my Tuesday afternoons are my most productive and now protect that time religiously.",
      author: "Emily Rodriguez",
      role: "Product Manager @ Linear",
      avatar: "ER"
    }
  ];

  return (
    <section className="py-24 md:py-32 bg-[#0A0A0A]">
      <div className="max-w-6xl mx-auto px-6">
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight mb-6 text-white">
            Loved by productive people
          </h2>
        </div>

        <div className="grid md:grid-cols-3 gap-6">
          {testimonials.map((t, i) => (
            <div
              key={i}
              className="p-8 rounded-2xl bg-zinc-900/30 border border-zinc-800 hover:border-zinc-700 transition-all"
            >
              <div className="flex items-center gap-1 mb-6">
                {[...Array(5)].map((_, j) => (
                  <Star key={j} className="w-5 h-5 text-amber-400 fill-amber-400" />
                ))}
              </div>
              <p className="text-zinc-300 leading-relaxed mb-6">"{t.quote}"</p>
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-gradient-to-br from-amber-400 to-amber-600 flex items-center justify-center text-black font-semibold">
                  {t.avatar}
                </div>
                <div>
                  <p className="font-semibold text-white">{t.author}</p>
                  <p className="text-sm text-zinc-500">{t.role}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}

function Pricing() {
  const features = [
    "Unlimited behavior analysis",
    "Daily & weekly insights",
    "Pattern recognition across weeks",
    "Narrative explanations",
    "Mac menu bar integration",
    "All data stored locally",
    "Free lifetime updates",
    "No subscription ever"
  ];

  return (
    <section id="pricing" className="py-24 md:py-32 bg-gradient-to-b from-[#0A0A0A] to-[#0F0F0F]">
      <div className="max-w-4xl mx-auto px-6">
        <div className="text-center mb-16">
          <h2 className="text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight mb-6 text-white">
            Simple, honest pricing
          </h2>
          <p className="text-xl text-zinc-400">
            One price. Own it forever. No subscriptions.
          </p>
        </div>

        <div className="relative">
          <div className="absolute -inset-4 bg-gradient-to-r from-amber-500/20 via-amber-400/10 to-amber-500/20 rounded-3xl blur-2xl opacity-50" />
          <div className="relative p-10 md:p-12 rounded-2xl bg-zinc-900/50 border border-zinc-800">
            <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-8 mb-10">
              <div>
                <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-amber-500/10 border border-amber-500/20 mb-4">
                  <span className="text-sm text-amber-400 font-medium">7-Day Free Trial</span>
                </div>
                <div className="flex items-baseline gap-2">
                  <span className="text-5xl md:text-6xl font-bold text-white">$49</span>
                  <span className="text-zinc-500">one-time</span>
                </div>
              </div>
              <a
                href="#download"
                className="bg-amber-500 hover:bg-amber-400 text-black font-semibold px-8 py-4 rounded-xl transition-all hover:shadow-xl hover:shadow-amber-500/30 flex items-center gap-2"
              >
                <Download className="w-5 h-5" />
                Start Free Trial
              </a>
            </div>

            <div className="grid sm:grid-cols-2 gap-4">
              {features.map((feature, i) => (
                <div key={i} className="flex items-center gap-3">
                  <CheckCircle className="w-5 h-5 text-amber-400 flex-shrink-0" />
                  <span className="text-zinc-300">{feature}</span>
                </div>
              ))}
            </div>

            <div className="mt-8 pt-8 border-t border-zinc-800 text-center">
              <p className="text-zinc-500">
                30-day money-back guarantee. No questions asked.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

function CTASection() {
  return (
    <section id="download" className="py-24 md:py-32 bg-[#0F0F0F] relative overflow-hidden">
      <div className="absolute inset-0 bg-gradient-to-t from-amber-500/5 to-transparent" />
      <div className="max-w-4xl mx-auto px-6 text-center relative z-10">
        <h2 className="text-4xl md:text-5xl lg:text-6xl font-bold tracking-tight mb-6 text-white">
          Ready to understand your time?
        </h2>
        <p className="text-xl text-zinc-400 mb-10 max-w-2xl mx-auto">
          Stop wondering where your day went. Start getting answers.
        </p>
        <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
          <a
            href="#"
            className="group bg-amber-500 hover:bg-amber-400 text-black font-semibold px-10 py-5 rounded-xl transition-all hover:shadow-xl hover:shadow-amber-500/30 flex items-center gap-3 text-lg"
          >
            <Apple className="w-6 h-6" />
            Download for Mac
            <ChevronRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
          </a>
        </div>
        <p className="text-zinc-500 mt-6 text-sm">
          Requires macOS 13 Ventura or later
        </p>
      </div>
    </section>
  );
}

function Footer() {
  return (
    <footer className="py-12 bg-[#0A0A0A] border-t border-zinc-800/50">
      <div className="max-w-6xl mx-auto px-6">
        <div className="flex flex-col md:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-amber-400 to-amber-600 flex items-center justify-center">
              <Clock className="w-5 h-5 text-black" />
            </div>
            <span className="text-lg font-semibold">Chronote</span>
          </div>

          <div className="flex items-center gap-8">
            <a href="#" className="text-zinc-500 hover:text-white transition-colors text-sm">Privacy</a>
            <a href="#" className="text-zinc-500 hover:text-white transition-colors text-sm">Terms</a>
            <a href="#" className="text-zinc-500 hover:text-white transition-colors text-sm">Support</a>
            <a href="https://twitter.com" className="text-zinc-500 hover:text-white transition-colors text-sm">Twitter</a>
          </div>

          <p className="text-zinc-600 text-sm">
            Made with care for Mac
          </p>
        </div>
      </div>
    </footer>
  );
}

export default App;
