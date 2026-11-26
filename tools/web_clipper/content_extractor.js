(() => {
  if (globalThis.__jibunWebClipperExtract) {
    return globalThis.__jibunWebClipperExtract();
  }

  function convertNodeToMarkdown(node) {
    if (!node) return '';
    if (node.nodeType === Node.TEXT_NODE) {
      return (node.textContent || '').replace(/\s+/g, ' ');
    }
    if (node.nodeType !== Node.ELEMENT_NODE) return '';

    const tag = node.tagName.toLowerCase();
    if (['script', 'style', 'noscript', 'svg', 'iframe', 'nav', 'footer'].includes(tag)) {
      return '';
    }

    const childrenMd = Array.from(node.childNodes).map(convertNodeToMarkdown).join('');
    const trimmed = childrenMd.trim();

    switch (tag) {
      case 'h1':
        return trimmed ? `\n# ${trimmed}\n\n` : '';
      case 'h2':
        return trimmed ? `\n## ${trimmed}\n\n` : '';
      case 'h3':
        return trimmed ? `\n### ${trimmed}\n\n` : '';
      case 'h4':
        return trimmed ? `\n#### ${trimmed}\n\n` : '';
      case 'p':
      case 'section':
      case 'article':
        return trimmed ? `${trimmed}\n\n` : '';
      case 'br':
        return '\n';
      case 'strong':
      case 'b':
        return trimmed ? `**${trimmed}**` : '';
      case 'em':
      case 'i':
        return trimmed ? `*${trimmed}*` : '';
      case 'code':
        if (node.parentElement && node.parentElement.tagName.toLowerCase() === 'pre') {
          return node.textContent || '';
        }
        return trimmed ? `\`${trimmed}\`` : '';
      case 'pre': {
        const rawCode = (node.textContent || '').trimEnd();
        return rawCode ? `\n\`\`\`\n${rawCode}\n\`\`\`\n\n` : '';
      }
      case 'blockquote':
        return trimmed
          ? `${trimmed
              .split(/\r?\n/)
              .map((line) => `> ${line}`)
              .join('\n')}\n\n`
          : '';
      case 'a': {
        const href = node.getAttribute('href');
        if (!href) return trimmed;
        try {
          const resolved = new URL(href, location.href).toString();
          if (!resolved.startsWith('http://') && !resolved.startsWith('https://')) {
            return trimmed;
          }
          return `[${trimmed || resolved}](${resolved})`;
        } catch {
          return trimmed;
        }
      }
      case 'img': {
        const src = node.getAttribute('src');
        if (!src) return '';
        try {
          const resolved = new URL(src, location.href).toString();
          if (!resolved.startsWith('http://') && !resolved.startsWith('https://')) {
            return '';
          }
          const alt = (node.getAttribute('alt') || 'image').replace(/[\[\]]/g, '');
          return `![${alt}](${resolved})`;
        } catch {
          return '';
        }
      }
      case 'li':
        return trimmed ? `- ${trimmed}\n` : '';
      case 'ul':
      case 'ol':
        return trimmed ? `${trimmed}\n` : '';
      default:
        return childrenMd;
    }
  }

  globalThis.__jibunWebClipperExtract = () => {
    const selection = (window.getSelection?.()?.toString() || '').trim();
    const metaDesc =
      document.querySelector('meta[name="description"]')?.getAttribute('content') || '';

    let title = document.title || '';
    let excerpt = metaDesc;
    let markdownBody = '';
    let engine = 'semantic-fallback';

    if (typeof globalThis.Readability === 'function') {
      try {
        const docClone = document.cloneNode(true);
        const parsed = new globalThis.Readability(docClone).parse();
        if (parsed && parsed.content) {
          title = parsed.title || title;
          excerpt = parsed.excerpt || excerpt;
          if (typeof globalThis.TurndownService === 'function') {
            const turndown = new globalThis.TurndownService({
              headingStyle: 'atx',
              codeBlockStyle: 'fenced',
            });
            markdownBody = turndown.turndown(parsed.content).trim();
            engine = 'readability+turndown';
          } else {
            const wrapper = document.createElement('div');
            wrapper.innerHTML = parsed.content;
            markdownBody = convertNodeToMarkdown(wrapper)
              .replace(/\n{3,}/g, '\n\n')
              .trim();
            engine = 'readability+fallback-md';
          }
        }
      } catch {
        // Fall back to semantic DOM extractor below.
      }
    }

    if (!markdownBody) {
      const root =
        document.querySelector('article') ||
        document.querySelector('main') ||
        document.body;
      markdownBody = convertNodeToMarkdown(root)
        .replace(/\n{3,}/g, '\n\n')
        .trim();
    }

    return {
      title: title.trim(),
      url: location.href,
      excerpt: (excerpt || '').trim(),
      selectedText: selection,
      markdownBody,
      engine,
    };
  };

  return globalThis.__jibunWebClipperExtract();
})();
