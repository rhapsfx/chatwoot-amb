<script>
export default {
  name: 'AppleIMessageAppBubble',
  props: {
    bid: {
      type: String,
      required: true,
    },
    receivedMessage: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      appIcon: null,
      appName: '',
      appSubtitle: '',
      appDescription: '',
      loading: true,
      imageError: false,
    };
  },
  async mounted() {
    await this.fetchAppMetadata();
  },
  methods: {
    async fetchAppMetadata() {
      try {
        // Extract bundle ID from BID format
        // Example: "com.apple.messages.MSMessageExtensionBalloonPlugin:4GWDBCF5A4:com.shazam.Shazam.imessageextension"
        // We want: "com.shazam.Shazam"
        const bundleId = this.extractBundleId(this.bid);

        // Fetch app metadata from iTunes Lookup API
        const response = await fetch(
          `https://itunes.apple.com/lookup?bundleId=${bundleId}`
        );
        const data = await response.json();

        if (data.resultCount > 0) {
          const app = data.results[0];
          this.appIcon =
            app.artworkUrl512 || app.artworkUrl100 || app.artworkUrl60;
          this.appName = app.trackName || this.receivedMessage.title;
          this.appSubtitle = this.receivedMessage.subtitle || '';
          this.appDescription = app.primaryGenreName || '';
        } else {
          // No results from iTunes API, use fallback
          this.useFallbackData();
        }
      } catch (error) {
        // Error fetching app metadata, use fallback
        this.useFallbackData();
      } finally {
        this.loading = false;
      }
    },

    extractBundleId(bid) {
      // BID format: "com.apple.messages.MSMessageExtensionBalloonPlugin:teamId:bundleId.imessageextension"
      // Extract the last part and remove .imessageextension suffix
      const parts = bid.split(':');
      if (parts.length >= 3) {
        const lastPart = parts[parts.length - 1];
        return lastPart.replace('.imessageextension', '');
      }
      return bid;
    },

    useFallbackData() {
      // Use fallback App Store icon
      this.appIcon = '/_apple/AppStore-1024.png';
      this.appName = this.receivedMessage.title || 'iMessage App';
      this.appSubtitle = this.receivedMessage.subtitle || '';
      this.appDescription = '';
    },

    handleImageError() {
      if (!this.imageError) {
        this.imageError = true;
        this.appIcon = '/_apple/AppStore-1024.png';
      }
    },
  },
};
</script>

<template>
  <div class="imessage-app-bubble">
    <div v-if="loading" class="loading-state">
      <span class="spinner" />
      <span class="loading-text">{{ $t('APPLE_MESSAGES.LOADING_APP') }}</span>
    </div>
    <div v-else class="app-content">
      <img
        :src="appIcon"
        :alt="appName"
        class="app-icon"
        @error="handleImageError"
      />
      <div class="app-info">
        <h4 class="app-name">{{ appName }}</h4>
        <p v-if="appSubtitle" class="app-subtitle">{{ appSubtitle }}</p>
        <p v-if="appDescription" class="app-description">
          {{ appDescription }}
        </p>
      </div>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.imessage-app-bubble {
  display: flex;
  align-items: center;
  padding: var(--space-small);
  background: var(--white);
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius-large);
  max-width: 400px;
  margin: var(--space-small) 0;
  box-shadow: var(--shadow-small);

  .loading-state {
    display: flex;
    align-items: center;
    gap: var(--space-small);
    padding: var(--space-small);

    .spinner {
      display: inline-block;
      width: 16px;
      height: 16px;
      border: 2px solid var(--color-border);
      border-top-color: var(--w-500);
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }

    .loading-text {
      color: var(--s-600);
      font-size: var(--font-size-mini);
    }
  }

  .app-content {
    display: flex;
    align-items: center;
    gap: var(--space-small);
    width: 100%;

    .app-icon {
      width: 60px;
      height: 60px;
      border-radius: var(--border-radius-normal);
      flex-shrink: 0;
      object-fit: cover;
      box-shadow: var(--shadow-small);
    }

    .app-info {
      flex: 1;
      min-width: 0;

      .app-name {
        margin: 0;
        font-size: var(--font-size-default);
        font-weight: var(--font-weight-medium);
        color: var(--s-900);
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }

      .app-subtitle {
        margin: var(--space-micro) 0 0;
        font-size: var(--font-size-mini);
        color: var(--s-600);
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }

      .app-description {
        margin: var(--space-micro) 0 0;
        font-size: var(--font-size-mini);
        color: var(--s-500);
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }
    }
  }
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

// Dark mode support
.dark {
  .imessage-app-bubble {
    background: var(--s-800);
    border-color: var(--s-700);

    .app-content {
      .app-info {
        .app-name {
          color: var(--s-50);
        }

        .app-subtitle {
          color: var(--s-300);
        }

        .app-description {
          color: var(--s-400);
        }
      }
    }
  }
}
</style>
