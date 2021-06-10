/**
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { EventEmitter } from 'common/events';
import { classes } from 'common/react';
import { createLogger } from 'tgui/logging';
import { COMBINE_MAX_MESSAGES, COMBINE_MAX_TIME_WINDOW, IMAGE_RETRY_DELAY, IMAGE_RETRY_LIMIT, IMAGE_RETRY_MESSAGE_AGE, MAX_PERSISTED_MESSAGES, MAX_VISIBLE_MESSAGES, MESSAGE_PRUNE_INTERVAL, MESSAGE_TYPES, MESSAGE_TYPE_INTERNAL, MESSAGE_TYPE_UNKNOWN } from './constants';
import { canPageAcceptType, createMessage, isSameMessage } from './model';
import { highlightNode, linkifyNode, replaceInTextNode } from './replaceInTextNode';

const logger = createLogger('chatRenderer');

// We consider this as the smallest possible scroll offset
// that is still trackable.
const SCROLL_TRACKING_TOLERANCE = 24;

const findNearestScrollableParent = startingNode => {
  const body = document.body;
  let node = startingNode;
  while (node && node !== body) {
    // This definitely has a vertical scrollbar, because it reduces
    // scrollWidth of the element. Might not work if element uses
    // overflow: hidden.
    if (node.scrollWidth < node.offsetWidth) {
      return node;
    }
    node = node.parentNode;
  }
  return window;
};

const createHighlightNode = (text, color) => {
  const node = document.createElement('span');
  node.className = 'Chat__highlight';
  node.setAttribute('style', 'background-color:' + color);
  node.textContent = text;
  return node;
};

const createMessageNode = () => {
  const node = document.createElement('div');
  node.className = 'ChatMessage';
  return node;
};

const createReconnectedNode = () => {
  const node = document.createElement('div');
  node.className = 'Chat__reconnected';
  return node;
};

// Removes job formatting
const formatHighContrast = inputHtml => {
  const replacementNodes = [
    "unknown",
    "assistant",
    "atmospherictechnician",
    "bartender",
    "botanist",
    "brigphysician",
    "captain",
    "cargotechnician",
    "chaplain",
    "chemist",
    "chiefengineer",
    "chiefmedicalofficer",
    "clown",
    "cook",
    "curator",
    "deputy",
    "detective",
    "paramedic",
    "geneticist",
    "headofpersonnel",
    "headofsecurity",
    "janitor",
    "lawyer",
    "medicaldoctor",
    "mime",
    "quartermaster",
    "researchdirector",
    "roboticist",
    "scientist",
    "securityofficer",
    "shaftminer",
    "stationengineer",
    "virologist",
    "warden",
    "centcom",
    "prisoner",
    "blob",
    "corgi",
    "fox",
    "rainbow",
    "hierosay",
    "brassmobsay",
    "syndmob",
    "alienmobsay",
    "cultmobsay",
    "slimemobsay",
    "gimmick",
    "barber",
    "stagemagician",
    "debtor",
    "psychiatrist",
    "vip",
  ];
  const spanRegex = new RegExp('(<span[\\w| |\t|=]*[\'|"][\\w| ]*)(?:' + replacementNodes.join('|') + ')([\'|"]>)', 'gi');
  return inputHtml.replace(spanRegex, '$1$2');
};

const handleImageError = e => {
  setTimeout(() => {
    /** @type {HTMLImageElement} */
    const node = e.target;
    const attempts = parseInt(node.getAttribute('data-reload-n'), 10) || 0;
    if (attempts >= IMAGE_RETRY_LIMIT) {
      logger.error(`failed to load an image after ${attempts} attempts`);
      return;
    }
    const src = node.src;
    node.src = null;
    node.src = src + '#' + attempts;
    node.setAttribute('data-reload-n', attempts + 1);
  }, IMAGE_RETRY_DELAY);
};

/**
 * Assigns a "times-repeated" badge to the message.
 */
const updateMessageBadge = message => {
  const { node, times } = message;
  if (!node || !times) {
    // Nothing to update
    return;
  }
  const foundBadge = node.querySelector('.Chat__badge');
  const badge = foundBadge || document.createElement('div');
  badge.textContent = times;
  badge.className = classes([
    'Chat__badge',
    'Chat__badge--animate',
  ]);
  requestAnimationFrame(() => {
    badge.className = 'Chat__badge';
  });
  if (!foundBadge) {
    node.appendChild(badge);
  }
};

class ChatRenderer {
  constructor() {
    /** @type {HTMLElement} */
    this.loaded = false;
    /** @type {HTMLElement} */
    this.rootNode = null;
    this.queue = [];
    this.messages = [];
    this.visibleMessages = [];
    this.page = null;
    this.events = new EventEmitter();
    // Scroll handler
    /** @type {HTMLElement} */
    this.scrollNode = null;
    this.scrollTracking = true;
    this.handleScroll = type => {
      const node = this.scrollNode;
      const height = node.scrollHeight;
      const bottom = node.scrollTop + node.offsetHeight;
      const scrollTracking = (
        Math.abs(height - bottom) < SCROLL_TRACKING_TOLERANCE
      );
      if (scrollTracking !== this.scrollTracking) {
        this.scrollTracking = scrollTracking;
        this.events.emit('scrollTrackingChanged', scrollTracking);
        logger.debug('tracking', this.scrollTracking);
      }
    };
    this.ensureScrollTracking = () => {
      if (this.scrollTracking) {
        this.scrollToBottom();
      }
    };
    // Periodic message pruning
    setInterval(() => this.pruneMessages(), MESSAGE_PRUNE_INTERVAL);
  }

  isReady() {
    return this.loaded && this.rootNode && this.page;
  }

  mount(node) {
    // Mount existing root node on top of the new node
    if (this.rootNode) {
      node.appendChild(this.rootNode);
    }
    // Initialize the root node
    else {
      this.rootNode = node;
    }
    // Find scrollable parent
    this.scrollNode = findNearestScrollableParent(this.rootNode);
    this.scrollNode.addEventListener('scroll', this.handleScroll);
    setImmediate(() => {
      this.scrollToBottom();
    });
    // Flush the queue
    this.tryFlushQueue();
  }

  onStateLoaded() {
    this.loaded = true;
    this.tryFlushQueue();
  }

  tryFlushQueue() {
    if (this.isReady() && this.queue.length > 0) {
      this.processBatch(this.queue);
      this.queue = [];
    }
  }

  assignStyle(style = {}) {
    for (let key of Object.keys(style)) {
      this.rootNode.style.setProperty(key, style[key]);
    }
  }

  setHighlight(text, color) {
    if (!text || !color) {
      this.highlightRegex = null;
      this.highlightColor = null;
      return;
    }
    const allowedRegex = /^[a-z0-9_\-\s]+$/ig;
    const lines = String(text)
      .split(',')
      .map(str => str.trim())
      .filter(str => (
        // Must be longer than one character
        str && str.length > 1
        // Must be alphanumeric (with some punctuation)
        && allowedRegex.test(str)
      ));
    // Nothing to match, reset highlighting
    if (lines.length === 0) {
      this.highlightRegex = null;
      this.highlightColor = null;
      return;
    }
    this.highlightRegex = new RegExp('(' + lines.join('|') + ')', 'gi');
    this.highlightColor = color;
  }

  setHighContrast(newValue) {
    if (newValue === this.highContrast) {
      return;
    }
    this.highContrast = newValue;
    this.rebuildChat();
  }

  scrollToBottom() {
    // scrollHeight is always bigger than scrollTop and is
    // automatically clamped to the valid range.
    this.scrollNode.scrollTop = this.scrollNode.scrollHeight;
  }

  changePage(page) {
    if (!this.isReady()) {
      this.page = page;
      this.tryFlushQueue();
      return;
    }
    this.page = page;
    // Fast clear of the root node
    this.rootNode.textContent = '';
    this.visibleMessages = [];
    // Re-add message nodes
    const fragment = document.createDocumentFragment();
    let node;
    for (let message of this.messages) {
      if (canPageAcceptType(page, message.type)) {
        node = message.node;
        fragment.appendChild(node);
        this.visibleMessages.push(message);
      }
    }
    if (node) {
      this.rootNode.appendChild(fragment);
      node.scrollIntoView();
    }
  }

  getCombinableMessage(predicate) {
    const now = Date.now();
    const len = this.visibleMessages.length;
    const from = len - 1;
    const to = Math.max(0, len - COMBINE_MAX_MESSAGES);
    for (let i = from; i >= to; i--) {
      const message = this.visibleMessages[i];
      const matches = (
        // Is not an internal message
        !message.type.startsWith(MESSAGE_TYPE_INTERNAL)
        // Text payload must fully match
        && isSameMessage(message, predicate)
        // Must land within the specified time window
        && now < message.createdAt + COMBINE_MAX_TIME_WINDOW
      );
      if (matches) {
        return message;
      }
    }
    return null;
  }
  spellCheckPanel(text) {
    if (!text) {
      this.spellCheckblacklist = null;
      return;
    }
    text = text.trim();
    if (text === '') {
      this.spellCheckblacklist = null;
      return;
    }
    text = text.toLowerCase().replace(/[^а-яА-ЯёЁ ]/g, ' ').trim().split(' ');
    let exceps = [];
    for (let i = 0, len = text.length; i < len; i++) {
      if (exceps.indexOf(text[i]) > -1) continue;
      if (text[i].length >= 3) exceps.push(text[i]);
    }
    text = exceps.join(', ');
    let blackListt = text.replace(new RegExp(/,\s*/g), '|');
    let regex = '(?:\\s|^)(?:' + blackListt + ')\\S*';
    this.spellCheckblacklist = new RegExp(regex, 'g');
    logger.log(regex);
  }



  byondDecode(message) {
    message = message.replace(/\+/g, "%20");
    try {
      if (decodeURIComponent) {
        message = decodeURIComponent(message);
      } else {
        throw new Error("Easiest way to trigger the fallback");
      }
    } catch (err) {
      message = unescape(message);
    }
    return message;
  }
  spellCheck(text) {
    if (!text) return;

    text = this.filterText(text);

    if (text.length > 3) {
      this.sendYandexSpellerRequest(encodeURIComponent(text));
    }
  }
  filterText(text) {
    text = this.byondDecode(text);
    text = text.toLowerCase();
    text = text.replace(/[^а-яА-ЯёЁ ]/g, ' ');
    text = text.replace(/\s+/g, ' ');
    text = this.removeBlacklistedWords(text);
    text = this.getUniqueWords(text);
    return text;
  }
  getUniqueWords(text) {
    let words = text.split(' ');
    let uniqueWords = [];

    for (let i=0; i < words.length; i++) {
      if (words[i].length <= 3) continue;
      if (uniqueWords.indexOf(words[i]) > -1) continue;

      uniqueWords.push(words[i]);
    }
    return uniqueWords.join(' ');
  }
  removeBlacklistedWords(text) {
    return text.replace(this.spellCheckblacklist, '');
  }
  sendYandexSpellerRequest(text) {
    let xhr = new XMLHttpRequest();
    let fired = false;
    xhr.onreadystatechange = () => {
      if (xhr.readyState === 4) {
        if (xhr.status === 200) {
          if (!fired) {
            fired = true;
            let data = JSON.parse(xhr.responseText);
            this.markWords(data);
          }
        }
      }
    };
    xhr.open("GET", "http://speller.yandex.net/services/spellservice.json/checkText?options=512&lang=ru&text=" + text, true);
    xhr.send();
  }
  markWords(data) {
    if (!data || data === '[]') return;
    let ToShow = '';

    for (let i = 0, len = data.length; i < len; i++) {
      let subst = data[i];
      if (subst.s.length === 0) continue;

      let replacement = '';
      if (ToShow.length) replacement += ', ';

      if (subst.s.length === 1) {
        replacement += '<span class="line-good">'+subst.s[0]+'</span>';
      } else {
        replacement += '<span class="line-sugg">'+subst.s.join(', ')+'</span>';
      }

      ToShow += replacement+' - <span class="line-bad">'+subst.word+'</span>';
    }

    if (ToShow.length) {
      ToShow = '<span class="spellChecker">Возможные орфографические ошибки: '+ToShow+'</span>';
      let super_batch = [
        createMessage({
          html: ToShow,
        }),
      ];
      this.processBatch(super_batch);
    }
  }
  processBatch(batch, options = {}) {
    const {
      prepend,
      notifyListeners = true,
    } = options;
    const now = Date.now();
    // Queue up messages until chat is ready
    if (!this.isReady()) {
      if (prepend) {
        this.queue = [...batch, ...this.queue];
      }
      else {
        this.queue = [...this.queue, ...batch];
      }
      return;
    }
    // Insert messages
    const fragment = document.createDocumentFragment();
    const countByType = {};
    let node;
    for (let payload of batch) {
      const message = createMessage(payload);
      // Combine messages
      const combinable = this.getCombinableMessage(message);
      if (combinable) {
        combinable.times = (combinable.times || 1) + 1;
        updateMessageBadge(combinable);
        continue;
      }
      // Reuse message node
      if (message.node) {
        node = message.node;
      }
      // Reconnected
      else if (message.type === 'internal/reconnected') {
        node = createReconnectedNode();
      }
      else if (message.type === 'external/spell_check') {
        if (message.text) {
          let message_text = message.text;
          this.spellCheck(message_text);
        }
        // hack to fuck off spell checking message twice
        message.text = null;
      }
      // Create message node
      else {
        node = createMessageNode();
        // Payload is plain text
        if (message.text) {
          node.textContent = message.text;
        }
        // Payload is HTML
        else if (message.html) {
          if (this.highContrast) {
            node.innerHTML = formatHighContrast(message.html);
          }
          else {
            node.innerHTML = message.html;
          }
        }
        else {
          logger.error('Error: message is missing text payload', message);
        }
        // Highlight text
        if (!message.avoidHighlighting && this.highlightRegex) {
          const highlighted = highlightNode(node,
            this.highlightRegex,
            text => (
              createHighlightNode(text, this.highlightColor)
            ));
          if (highlighted) {
            node.className += ' ChatMessage--highlighted';
          }
        }
        // Linkify text
        if (message.allowLinkify) {
          linkifyNode(node);
        }
        // Assign an image error handler
        if (now < message.createdAt + IMAGE_RETRY_MESSAGE_AGE) {
          const imgNodes = node.querySelectorAll('img');
          for (let i = 0; i < imgNodes.length; i++) {
            const imgNode = imgNodes[i];
            imgNode.addEventListener('error', handleImageError);
          }
        }
      }
      // Store the node in the message
      message.node = node;
      // Query all possible selectors to find out the message type
      if (!message.type) {
        // IE8: Does not support querySelector on elements that
        // are not yet in the document.
        const typeDef = !Byond.IS_LTE_IE8 && MESSAGE_TYPES
          .find(typeDef => (
            typeDef.selector && node.querySelector(typeDef.selector)
          ));
        message.type = typeDef?.type || MESSAGE_TYPE_UNKNOWN;
      }
      updateMessageBadge(message);
      if (!countByType[message.type]) {
        countByType[message.type] = 0;
      }
      countByType[message.type] += 1;
      // TODO: Detect duplicates
      this.messages.push(message);
      if (canPageAcceptType(this.page, message.type)) {
        fragment.appendChild(node);
        this.visibleMessages.push(message);
      }
    }
    if (node) {
      const firstChild = this.rootNode.childNodes[0];
      if (prepend && firstChild) {
        this.rootNode.insertBefore(fragment, firstChild);
      }
      else {
        this.rootNode.appendChild(fragment);
      }
      if (this.scrollTracking) {
        setImmediate(() => this.scrollToBottom());
      }
    }
    // Notify listeners that we have processed the batch
    if (notifyListeners) {
      this.events.emit('batchProcessed', countByType);
    }
  }

  pruneMessages() {
    if (!this.isReady()) {
      return;
    }
    // Delay pruning because user is currently interacting
    // with chat history
    if (!this.scrollTracking) {
      logger.debug('pruning delayed');
      return;
    }
    // Visible messages
    {
      const messages = this.visibleMessages;
      const fromIndex = Math.max(0,
        messages.length - MAX_VISIBLE_MESSAGES);
      if (fromIndex > 0) {
        this.visibleMessages = messages.slice(fromIndex);
        for (let i = 0; i < fromIndex; i++) {
          const message = messages[i];
          this.rootNode.removeChild(message.node);
          // Mark this message as pruned
          message.node = 'pruned';
        }
        // Remove pruned messages from the message array
        this.messages = this.messages.filter(message => (
          message.node !== 'pruned'
        ));
        logger.log(`pruned ${fromIndex} visible messages`);
      }
    }
    // All messages
    {
      const fromIndex = Math.max(0,
        this.messages.length - MAX_PERSISTED_MESSAGES);
      if (fromIndex > 0) {
        this.messages = this.messages.slice(fromIndex);
        logger.log(`pruned ${fromIndex} stored messages`);
      }
    }
  }

  rebuildChat() {
    if (!this.isReady()) {
      return;
    }
    // Make a copy of messages
    const fromIndex = Math.max(0,
      this.messages.length - MAX_PERSISTED_MESSAGES);
    const messages = this.messages.slice(fromIndex);
    // Remove existing nodes
    for (let message of messages) {
      message.node = undefined;
    }
    // Fast clear of the root node
    this.rootNode.textContent = '';
    this.messages = [];
    this.visibleMessages = [];
    // Repopulate the chat log
    this.processBatch(messages, {
      notifyListeners: false,
    });
  }

  saveToDisk() {
    // Allow only on IE11
    if (Byond.IS_LTE_IE10) {
      return;
    }
    // Compile currently loaded stylesheets as CSS text
    let cssText = '';
    const styleSheets = document.styleSheets;
    for (let i = 0; i < styleSheets.length; i++) {
      const cssRules = styleSheets[i].cssRules;
      for (let i = 0; i < cssRules.length; i++) {
        const rule = cssRules[i];
        cssText += rule.cssText + '\n';
      }
    }
    cssText += 'body, html { background-color: #141414 }\n';
    // Compile chat log as HTML text
    let messagesHtml = '';
    for (let message of this.messages) {
      if (message.node) {
        messagesHtml += message.node.outerHTML + '\n';
      }
    }
    // Create a page
    const pageHtml = '<!doctype html>\n'
      + '<html>\n'
      + '<head>\n'
      + '<title>SS13 Chat Log</title>\n'
      + '<style>\n' + cssText + '</style>\n'
      + '</head>\n'
      + '<body>\n'
      + '<div class="Chat">\n'
      + messagesHtml
      + '</div>\n'
      + '</body>\n'
      + '</html>\n';
    // Create and send a nice blob
    const blob = new Blob([pageHtml]);
    const timestamp = new Date()
      .toISOString()
      .substring(0, 19)
      .replace(/[-:]/g, '')
      .replace('T', '-');
    window.navigator.msSaveBlob(blob, `ss13-chatlog-${timestamp}.html`);
  }
}

// Make chat renderer global so that we can continue using the same
// instance after hot code replacement.
if (!window.__chatRenderer__) {
  window.__chatRenderer__ = new ChatRenderer();
}

/** @type {ChatRenderer} */
export const chatRenderer = window.__chatRenderer__;
