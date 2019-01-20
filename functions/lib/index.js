"use strict";
// vikas was here!
Object.defineProperty(exports, "__esModule", { value: true });
// MARK: Modules
const admin = require("firebase-admin");
const functions = require("firebase-functions");
const Parser = require("rss-parser");
const node_firestore_import_export_1 = require("node-firestore-import-export");
// MARK: Init
admin.initializeApp();
// MARK: Types
class Article {
    constructor(source, title, url, category, date) {
        this.source = source;
        this.title = title;
        this.url = url;
        this.category = category;
        this.date = date;
    }
    toJSON() {
        return {
            source: this.source,
            title: this.title,
            url: this.url,
            category: this.category,
            date: this.date
        };
    }
}
// MARK: Properties
const db = admin.firestore();
const sources = [
    'Repubblica',
    'Corriere',
    'Il Foglio',
    'La Stampa',
    'Il Sole 24 Ore',
    'Gazzetta'
];
const hard = {
    'Repubblica': [
        'http://www.repubblica.it/rss/esteri/rss2.0.xml',
        'http://www.repubblica.it/rss/economia/rss2.0.xml',
        'http://www.repubblica.it/rss/politica/rss2.0.xml'
    ],
    'Corriere': [
        'http://xml2.corriereobjects.it/rss/politica.xml',
        'http://xml2.corriereobjects.it/rss/esteri.xml',
        'http://xml2.corriereobjects.it/rss/economia.xml'
    ],
    'Il Foglio': [
        'https://www.ilfoglio.it/rss.jsp?sezione=121',
        'https://www.ilfoglio.it/rss.jsp?sezione=116',
        'https://www.ilfoglio.it/rss.jsp?sezione=117',
        'https://www.ilfoglio.it/rss.jsp?sezione=325'
    ],
    'La Stampa': [
        'http://feed.lastampa.it/politica.rss',
        'http://feed.lastampa.it/esteri.rss',
        'http://feed.lastampa.it/economia.rss'
    ],
    'Il Sole 24 Ore': ['http://www.ilsole24ore.com/rss/primapagina.xml']
};
const soft = {
    'Repubblica': [
        'http://www.repubblica.it/rss/cronaca/rss2.0.xml',
        'http://www.repubblica.it/rss/sport/rss2.0.xml',
        'http://www.repubblica.it/rss/spettacoli_e_cultura/rss2.0.xml',
        'http://www.repubblica.it/rss/scienze/rss2.0.xml'
    ],
    'Corriere': [
        'http://xml2.corriereobjects.it/rss/cronache.xml',
        'http://xml2.corriereobjects.it/rss/cultura.xml',
        'http://xml2.corriereobjects.it/rss/spettacoli.xml',
        'http://xml2.corriereobjects.it/rss/cinema.xml',
        'http://xml2.corriereobjects.it/rss/sport.xml'
    ],
    'Il Foglio': [
        'https://www.ilfoglio.it/rss.jsp?sezione=316',
        'https://www.ilfoglio.it/rss.jsp?sezione=122',
        'https://www.ilfoglio.it/rss.jsp?sezione=293'
    ],
    'La Stampa': [
        'http://feed.lastampa.it/cultura.rss',
        'http://feed.lastampa.it/spettacoli.rss',
        'http://feed.lastampa.it/sport.rss',
        'http://feed.lastampa.it/costume.rss',
        'http://feed.lastampa.it/cronache.rss'
    ],
    'Gazzetta': ['http://www.gazzetta.it/rss/home.xml']
};
// MARK: Helper functions
const daysBetween = ((one, another) => {
    return Math.abs(one.getTime() - another.getTime()) / (1000 * 3600 * 24);
});
const shuffle = ((array) => {
    let i = array.length;
    if (i === 0)
        return array;
    while (--i) {
        const j = Math.floor(Math.random() * (i + 1));
        const temp = array[i];
        array[i] = array[j];
        array[j] = temp;
    }
    return array;
});
const auth = (token) => {
    return admin.auth().verifyIdToken(token);
};
const filtered = (feeds) => {
    const filteredFeed = shuffle([].concat.apply([], feeds.map(feed => {
        return feed.items.filter(item => {
            return (item.hasOwnProperty('title')
                && item.hasOwnProperty('link')
                && item.hasOwnProperty('isoDate')
                && daysBetween(new Date(), new Date(item['isoDate'])) < 2);
        });
    })));
    return filteredFeed;
};
const parseArticle = (data) => {
    return new Article(data.source.trim(), data.title.trim(), data.url.trim(), data.category.trim(), data.date.trim());
};
const getArticlesFrom = (feed, category) => {
    const articles = feed.map(item => {
        return parseArticle({
            source: sources.find(source => item.link.includes(source.toLowerCase().replace(/\s/g, ''))) || '–',
            title: item.title,
            url: item.link,
            category: category,
            date: item.isoDate
        });
    });
    return articles;
};
const getFeeds = (serve) => {
    const parser = new Parser();
    return Promise.all([].concat.apply([], Object.keys(serve).map(source => serve[source].map(url => parser.parseURL(url).catch(e => e)))));
};
const distribute = (one, another, distribution) => {
    const distributed = [];
    let i, j;
    switch (distribution) {
        case 'placebo':
            i = j = 5;
            break;
        case 'even':
            i = j = 1;
            break;
        case 'hard':
            i = 4;
            j = 1;
            break;
        case 'soft':
            i = 1;
            j = 4;
            break;
    }
    while (one.length && another.length)
        distributed.push(...one.splice(0, i).concat(another.splice(0, j)));
    if (one.length)
        distributed.push(...one.splice(0));
    if (another.length)
        distributed.push(...another.splice(0));
    return distributed;
};
// MARK: HTTPS functions
// POST
exports.markArticles = functions.https.onRequest((req, res) => {
    const token = req.get('Authorization').split('Bearer ')[1];
    const userID = req.query.userID;
    const read = req.query.read === 'true';
    const articles = JSON.parse(req.body.articles).map(parseArticle);
    const userRef = db.collection('users').doc(userID);
    const articlesRef = db.collection('articles');
    const readTime = req.body.elapsed;
    return Promise.all([auth(token), userRef.get(), articlesRef.get()]).then(results => {
        const decoded = results[0];
        const userSnapshot = results[1];
        const articlesSnapshot = results[2];
        const articlesDocs = !articlesSnapshot.empty ? articlesSnapshot.docs : [];
        // get article ids, uploading new ones along the way
        const newArticles = [];
        const existingArticleIDs = articles.filter(article => {
            for (let i = 0; i < articlesDocs.length; i++)
                if (articlesDocs[i].get('url') === article.url)
                    return true;
            newArticles.push(article);
            return false;
        }).map(article => {
            for (let i = 0; i < articlesDocs.length; i++)
                if (articlesDocs[i].get('url') === article.url)
                    return articlesDocs[i].id;
            return undefined;
        });
        return Promise.all(newArticles.map((newArticle) => {
            return articlesRef.add(newArticle.toJSON());
        })).then((newArticleDocs) => {
            const newArticleIDs = newArticleDocs.map((doc) => doc.id);
            const articleIDs = [].concat.apply([], [existingArticleIDs, newArticleIDs]);
            // then mark as seen or read
            const readOrSeen = read ? 'read' : 'seen';
            return Promise.all(articleIDs.map((id) => {
                const path = readOrSeen + '.' + id;
                if (read) {
                    return userRef.update({
                        [path]: {
                            'readDate': admin.firestore.FieldValue.serverTimestamp(),
                            'readTime': readTime
                        }
                    });
                }
                else {
                    return userRef.update({
                        [path + '.seenDate']: admin.firestore.FieldValue.serverTimestamp()
                    });
                }
            })).then(() => {
                res.status(200).end();
            });
        });
    }).catch(error => {
        console.log(error);
        res.send(error);
    });
});
exports.saveArticle = functions.https.onRequest((req, res) => {
    const token = req.get('Authorization').split('Bearer ')[1];
    const userID = req.query.userID;
    const userRef = db.collection('users').doc(userID);
    const article = parseArticle(JSON.parse(req.body.article));
    return db.runTransaction(transaction => {
        return Promise.all([auth(token), transaction.get(userRef)]).then(results => {
            const decoded = results[0];
            const userSnapshot = results[1];
            const saved = userSnapshot.get('saved') ? userSnapshot.get('saved') : [];
            if (saved.filter(item => item.url === article.url).length > 0) {
                res.status(304).end();
                const unique = {};
                return transaction.update(userRef, 'saved', saved.filter(item => {
                    if (unique.hasOwnProperty(item.url)) {
                        return false;
                    }
                    else {
                        unique[item.url] = true;
                        return true;
                    }
                }));
            }
            saved.push({
                source: article.source,
                title: article.title,
                url: article.url,
                category: article.category,
                date: article.date
            });
            res.status(200).end();
            return transaction.update(userRef, 'saved', saved);
        }).catch(error => {
            console.log(error);
            return res.send(error);
        });
    });
});
// GET
exports.exportDb = functions.https.onRequest((req, res) => {
    const pwd = req.get('Authentication');
    if (pwd !== functions.config().dossier.export_db_pwd) {
        return res.send(401);
    }
    return db.getCollections().then((collections) => {
        return Promise.all(collections.map(node_firestore_import_export_1.firestoreExport)).then((data) => {
            return res.send(JSON.stringify({ 'articles': data[0], 'users': data[1] }));
        }).catch(error => {
            return res.send(error);
        });
    }).catch(error => {
        return res.send(error);
    });
});
exports.sendArticlesToUser = functions.https.onRequest((req, res) => {
    const token = req.get('Authorization').split('Bearer ')[1];
    const distribution = req.query.distribution;
    return Promise.all([auth(token), getFeeds(hard), getFeeds(soft)]).then(results => {
        const decoded = results[0];
        const hardFeed = getArticlesFrom(filtered(results[1].filter((feed) => feed.items)), 'hard');
        const softFeed = getArticlesFrom(filtered(results[2].filter((feed) => feed.items)), 'soft');
        const distributed = distribute(hardFeed, softFeed, distribution);
        res.setHeader('Content-Type', 'application/json');
        return res.status(200).send(JSON.stringify(distributed));
    }).catch(error => {
        console.log(error);
        return res.send(error);
    });
});
exports.getSaved = functions.https.onRequest((req, res) => {
    const token = req.get('Authorization').split('Bearer ')[1];
    const userID = req.query.userID;
    const userRef = db.collection('users').doc(userID);
    return Promise.all([auth(token), userRef.get()]).then(results => {
        const decoded = results[0];
        const userSnapshot = results[1];
        const user = userSnapshot.data();
        const saved = user['saved'].map(parseArticle);
        res.setHeader('Content-Type', 'application/json');
        return res.status(200).send(JSON.stringify(saved));
    }).catch(error => {
        console.log(error);
        return res.send(error);
    });
});
exports.getProgress = functions.https.onRequest((req, res) => {
    const token = req.get('Authorization').split('Bearer ')[1];
    const userID = req.query.userID;
    const userRef = db.collection('users').doc(userID);
    return Promise.all([auth(token), userRef.get()]).then(results => {
        const decoded = results[0];
        const userSnapshot = results[1];
        const user = userSnapshot.data();
        const read = user['read'];
        if (!read) {
            return res.status(200).send([0, 0, 0]);
        }
        const articleIDs = Object.keys(read);
        const totalReadCount = articleIDs.length;
        let weeklyReadCount = 0;
        let totalReadTime = 0;
        articleIDs.forEach(id => {
            const readDate = new Date(read[id]['readDate']);
            const today = new Date();
            const dayDifference = Math.ceil(Math.abs(today.getTime() - readDate.getTime())) / (1000 * 3600 * 24);
            if (dayDifference <= 7) {
                weeklyReadCount++;
            }
            const readTime = read[id]['readTime'];
            totalReadTime += readTime;
        });
        totalReadTime = Math.ceil(totalReadTime / 60);
        return res.status(200).send([totalReadCount, weeklyReadCount, totalReadTime]);
    }).catch(error => {
        console.log(error);
        return res.send(error);
    });
});
//# sourceMappingURL=index.js.map