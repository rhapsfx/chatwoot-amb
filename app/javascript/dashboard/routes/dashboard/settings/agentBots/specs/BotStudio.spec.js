import { mount } from '@vue/test-utils';
import { vi } from 'vitest';
import BotStudio from '../BotStudio.vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

vi.mock('vue-router');
vi.mock('dashboard/composables/store');
vi.mock('dashboard/composables');

describe('BotStudio.vue', () => {
  let wrapper;
  let store;
  let mockRoute;
  let mockRouter;

  const createMockStore = () => ({
    dispatch: vi.fn(),
    getters: {
      'agentBots/getBot': vi.fn(() => ({
        id: 1,
        name: 'Test Bot',
        bot_type: 'apple_messages_for_business',
      })),
    },
  });

  beforeEach(() => {
    store = createMockStore();
    mockRoute = {
      params: {
        accountId: '1',
        botId: '1',
      },
    };
    mockRouter = {
      push: vi.fn(),
    };

    useRoute.mockReturnValue(mockRoute);
    useRouter.mockReturnValue(mockRouter);

    vi.mocked(useStore).mockReturnValue(store);
  });

  afterEach(() => {
    wrapper?.unmount();
    vi.clearAllMocks();
  });

  describe('Component Initialization', () => {
    it('should render the component', () => {
      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: true,
            NodePalette: true,
          },
        },
      });

      expect(wrapper.exists()).toBe(true);
    });

    it('should load bot data on mount', async () => {
      store.dispatch.mockResolvedValue({
        id: 1,
        name: 'Test Bot',
      });

      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: true,
            NodePalette: true,
          },
        },
      });

      await wrapper.vm.$nextTick();

      expect(store.dispatch).toHaveBeenCalledWith('agentBots/show', 1);
    });

    it('should load or create flow on mount', async () => {
      store.dispatch.mockResolvedValueOnce({}); // show bot
      store.dispatch.mockResolvedValueOnce({
        flows: [{ id: 2, name: 'Imported from bot_config' }],
      });

      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: true,
            NodePalette: true,
          },
        },
      });

      await wrapper.vm.$nextTick();
      await wrapper.vm.$nextTick();

      expect(store.dispatch).toHaveBeenCalledWith('agentBots/getFlows', 1);
    });
  });

  describe('Header Actions', () => {
    it('should have Import from JSON button', () => {
      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: true,
            NodePalette: true,
          },
        },
      });

      const buttons = wrapper.findAllComponents({ name: 'Button' });
      const importButton = buttons.find(b =>
        b.props('label')?.includes('IMPORT_FROM_JSON')
      );

      expect(importButton).toBeTruthy();
    });

    it('should have Save button', () => {
      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: true,
            NodePalette: true,
          },
        },
      });

      const buttons = wrapper.findAllComponents({ name: 'Button' });
      const saveButton = buttons.find(b => b.props('label')?.includes('SAVE'));

      expect(saveButton).toBeTruthy();
    });

    it('should have Compile & Test button', () => {
      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: true,
            NodePalette: true,
          },
        },
      });

      const buttons = wrapper.findAllComponents({ name: 'Button' });
      const compileButton = buttons.find(b =>
        b.props('label')?.includes('COMPILE_TEST')
      );

      expect(compileButton).toBeTruthy();
    });
  });

  describe('Toolbar Controls', () => {
    beforeEach(() => {
      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: {
              template: '<div ref="canvas"></div>',
              setup() {
                return {
                  searchQuery: '',
                  highlightedNodeIds: [],
                  canUndo: false,
                  canRedo: false,
                  canCopy: false,
                  canPaste: false,
                  isMac: false,
                  searchNodes: vi.fn(),
                  clearSearch: vi.fn(),
                  undo: vi.fn(),
                  redo: vi.fn(),
                  copyNodes: vi.fn(),
                  pasteNodes: vi.fn(),
                  duplicateNodes: vi.fn(),
                  deleteSelected: vi.fn(),
                  autoLayout: vi.fn(),
                  getFlowData: vi.fn(() => ({ nodes: [], edges: [] })),
                };
              },
            },
            NodePalette: true,
          },
        },
      });
    });

    it('should render search input', () => {
      const searchInput = wrapper.find('input[type="text"]');
      expect(searchInput.exists()).toBe(true);
      expect(searchInput.attributes('placeholder')).toBe('Search nodes...');
    });

    it('should render undo button', () => {
      const undoButton = wrapper.find('[title*="Undo"]');
      expect(undoButton.exists()).toBe(true);
    });

    it('should render redo button', () => {
      const redoButton = wrapper.find('[title*="Redo"]');
      expect(redoButton.exists()).toBe(true);
    });

    it('should render copy button', () => {
      const copyButton = wrapper.find('[title*="Copy"]');
      expect(copyButton.exists()).toBe(true);
    });

    it('should render paste button', () => {
      const pasteButton = wrapper.find('[title*="Paste"]');
      expect(pasteButton.exists()).toBe(true);
    });

    it('should render duplicate button', () => {
      const duplicateButton = wrapper.find('[title*="Duplicate"]');
      expect(duplicateButton.exists()).toBe(true);
    });

    it('should render delete button', () => {
      const deleteButton = wrapper.find('[title*="Delete"]');
      expect(deleteButton.exists()).toBe(true);
    });

    it('should render auto layout button', () => {
      const autoLayoutButton = wrapper.find('[title*="Auto-layout"]');
      expect(autoLayoutButton.exists()).toBe(true);
    });
  });

  describe('Save Flow', () => {
    it('should call getFlowData from canvas when saving', async () => {
      const mockGetFlowData = vi.fn(() => ({
        nodes: [{ id: 'node1', type: 'state' }],
        edges: [{ id: 'edge1', source: 'node1', target: 'node2' }],
      }));

      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: {
              template: '<div></div>',
              setup() {
                return {
                  getFlowData: mockGetFlowData,
                };
              },
            },
            NodePalette: true,
          },
        },
      });

      await wrapper.vm.$nextTick();

      // Set flowId
      wrapper.vm.flowId = 2;

      // Trigger save
      await wrapper.vm.handleSaveFlow();

      expect(mockGetFlowData).toHaveBeenCalled();
    });

    it('should dispatch updateFlow action when flowId exists', async () => {
      store.dispatch.mockResolvedValue({ flow: { id: 2 } });

      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: {
              template: '<div></div>',
              setup() {
                return {
                  getFlowData: vi.fn(() => ({
                    nodes: [{ id: 'node1' }],
                    edges: [],
                  })),
                };
              },
            },
            NodePalette: true,
          },
        },
      });

      wrapper.vm.flowId = 2;
      await wrapper.vm.handleSaveFlow();

      expect(store.dispatch).toHaveBeenCalledWith('agentBots/updateFlow', {
        botId: 1,
        flowId: 2,
        flow_data: {
          nodes: [{ id: 'node1' }],
          edges: [],
        },
      });
    });

    it('should dispatch createFlow action when flowId does not exist', async () => {
      store.dispatch.mockResolvedValue({ flow: { id: 3 } });

      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: {
              template: '<div></div>',
              setup() {
                return {
                  getFlowData: vi.fn(() => ({
                    nodes: [{ id: 'node1' }],
                    edges: [],
                  })),
                };
              },
            },
            NodePalette: true,
          },
        },
      });

      wrapper.vm.flowId = null;
      await wrapper.vm.handleSaveFlow();

      expect(store.dispatch).toHaveBeenCalledWith('agentBots/createFlow', {
        botId: 1,
        name: 'Imported from bot_config',
        flow_data: {
          nodes: [{ id: 'node1' }],
          edges: [],
        },
      });
    });

    it('should show error alert when canvas ref is not available', async () => {
      const mockUseAlert = vi.fn();
      vi.mocked(useAlert).mockReturnValue(mockUseAlert);

      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: true,
            NodePalette: true,
          },
        },
      });

      // canvasRef is null
      wrapper.vm.canvasRef = null;
      await wrapper.vm.handleSaveFlow();

      expect(mockUseAlert).toHaveBeenCalledWith(
        expect.stringContaining('ERROR_SAVING_FLOW')
      );
    });
  });

  describe('Compile Flow', () => {
    it('should dispatch compileFlow action', async () => {
      store.dispatch.mockResolvedValue({ success: true });

      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: true,
            NodePalette: true,
          },
        },
      });

      wrapper.vm.flowId = 2;
      await wrapper.vm.handleCompileFlow();

      expect(store.dispatch).toHaveBeenCalledWith('agentBots/compileFlow', {
        botId: 1,
        flowId: 2,
      });
    });

    it('should show error when flowId is null', async () => {
      const mockUseAlert = vi.fn();
      vi.mocked(useAlert).mockReturnValue(mockUseAlert);

      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: true,
            NodePalette: true,
          },
        },
      });

      wrapper.vm.flowId = null;
      await wrapper.vm.handleCompileFlow();

      expect(mockUseAlert).toHaveBeenCalledWith(
        expect.stringContaining('ERROR_COMPILING_FLOW')
      );
      expect(store.dispatch).not.toHaveBeenCalled();
    });
  });

  describe('Import from Bot Config', () => {
    it('should dispatch importFlowFromBotConfig action', async () => {
      store.dispatch.mockResolvedValue({
        flow: { id: 3, name: 'Imported from bot_config' },
      });

      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: true,
            NodePalette: true,
          },
        },
      });

      await wrapper.vm.handleImportFromBotConfig();

      expect(store.dispatch).toHaveBeenCalledWith(
        'agentBots/importFlowFromBotConfig',
        1
      );
    });
  });

  describe('Node Selection', () => {
    it('should update selectedNode when canvas emits node-selected', async () => {
      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: {
              template:
                '<div @click="$emit(\'node-selected\', testNode)"></div>',
              data() {
                return {
                  testNode: { id: 'node1', type: 'state' },
                };
              },
            },
            NodePalette: true,
          },
        },
      });

      const canvas = wrapper.findComponent({ name: 'BotStudioCanvas' });
      await canvas.trigger('click');

      expect(wrapper.vm.selectedNode).toEqual({
        id: 'node1',
        type: 'state',
      });
    });
  });

  describe('Navigation', () => {
    it('should navigate back to agent bots list', async () => {
      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: true,
            NodePalette: true,
          },
        },
      });

      await wrapper.vm.goBack();

      expect(mockRouter.push).toHaveBeenCalledWith({ name: 'agent_bots' });
    });
  });

  describe('Layout', () => {
    it('should render three-column layout', () => {
      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: true,
            NodePalette: true,
          },
        },
      });

      // Left column (NodePalette)
      expect(wrapper.findComponent({ name: 'NodePalette' }).exists()).toBe(
        true
      );

      // Center column (BotStudioCanvas)
      expect(wrapper.findComponent({ name: 'BotStudioCanvas' }).exists()).toBe(
        true
      );

      // Right column (Config Panel) - check for the empty state or editor
      const configPanel = wrapper.find('.min-w-56');
      expect(configPanel.exists()).toBe(true);
    });
  });

  describe('Error Handling', () => {
    it('should handle bot load failure', async () => {
      store.dispatch.mockRejectedValue(new Error('Bot not found'));
      const mockUseAlert = vi.fn();
      vi.mocked(useAlert).mockReturnValue(mockUseAlert);

      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: true,
            NodePalette: true,
          },
        },
      });

      await wrapper.vm.$nextTick();

      expect(mockUseAlert).toHaveBeenCalled();
      expect(mockRouter.push).toHaveBeenCalledWith({ name: 'agent_bots' });
    });

    it('should handle save flow failure', async () => {
      store.dispatch.mockRejectedValue(new Error('Save failed'));
      const mockUseAlert = vi.fn();
      vi.mocked(useAlert).mockReturnValue(mockUseAlert);

      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: {
              template: '<div></div>',
              setup() {
                return {
                  getFlowData: vi.fn(() => ({ nodes: [], edges: [] })),
                };
              },
            },
            NodePalette: true,
          },
        },
      });

      wrapper.vm.flowId = 2;
      await wrapper.vm.handleSaveFlow();

      expect(mockUseAlert).toHaveBeenCalledWith(
        expect.stringContaining('ERROR_SAVING_FLOW')
      );
    });

    it('should handle compile flow failure', async () => {
      store.dispatch.mockRejectedValue(new Error('Compile failed'));
      const mockUseAlert = vi.fn();
      vi.mocked(useAlert).mockReturnValue(mockUseAlert);

      wrapper = mount(BotStudio, {
        global: {
          stubs: {
            Button: true,
            BotStudioCanvas: true,
            NodePalette: true,
          },
        },
      });

      wrapper.vm.flowId = 2;
      await wrapper.vm.handleCompileFlow();

      expect(mockUseAlert).toHaveBeenCalledWith(
        expect.stringContaining('ERROR_COMPILING_FLOW')
      );
    });
  });
});
