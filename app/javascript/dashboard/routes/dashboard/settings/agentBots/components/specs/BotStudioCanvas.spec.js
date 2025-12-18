import { mount } from '@vue/test-utils';
import { vi } from 'vitest';
import { nextTick } from 'vue';
import BotStudioCanvas from '../BotStudioCanvas.vue';
import { VueFlow } from '@vue-flow/core';
import { useStore } from 'dashboard/composables/store';

vi.mock('@vue-flow/core', () => ({
  VueFlow: {
    name: 'VueFlow',
    template: '<div class="vue-flow-mock"><slot /></div>',
  },
  useVueFlow: () => ({
    onConnect: vi.fn(),
    addEdges: vi.fn(),
    fitView: vi.fn(),
    setInteractive: vi.fn(),
    fitBounds: vi.fn(),
    getSelectedNodes: { value: [] },
    getSelectedEdges: { value: [] },
    removeNodes: vi.fn(),
  }),
}));

vi.mock('@vue-flow/background', () => ({
  Background: { name: 'Background', template: '<div />' },
}));

vi.mock('@vue-flow/controls', () => ({
  Controls: { name: 'Controls', template: '<div />' },
}));

vi.mock('@vue-flow/minimap', () => ({
  MiniMap: { name: 'MiniMap', template: '<div />' },
}));

vi.mock('dashboard/composables/store');

describe('BotStudioCanvas.vue', () => {
  let wrapper;
  let mockStore;

  const createMockStore = () => ({
    dispatch: vi.fn(),
  });

  beforeEach(() => {
    mockStore = createMockStore();
    vi.mocked(useStore).mockReturnValue(mockStore);
  });

  afterEach(() => {
    wrapper?.unmount();
    vi.clearAllMocks();
  });

  describe('Component Initialization', () => {
    it('should render VueFlow component', () => {
      wrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: 2,
        },
      });

      expect(wrapper.findComponent(VueFlow).exists()).toBe(true);
    });

    it('should load flow data on mount when flowId is provided', async () => {
      mockStore.dispatch.mockResolvedValue({
        flow: {
          flow_data: {
            nodes: [{ id: 'node1', type: 'state' }],
            edges: [{ id: 'edge1', source: 'node1', target: 'node2' }],
          },
        },
      });

      wrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: 2,
        },
      });

      await nextTick();
      await nextTick();

      expect(mockStore.dispatch).toHaveBeenCalledWith('agentBots/getFlow', {
        botId: 1,
        flowId: 2,
      });
    });

    it('should not load flow when flowId is null', () => {
      wrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: null,
        },
      });

      expect(mockStore.dispatch).not.toHaveBeenCalled();
    });
  });

  describe('History Management (Undo/Redo)', () => {
    beforeEach(() => {
      mockStore.dispatch.mockResolvedValue({
        flow: {
          flow_data: {
            nodes: [{ id: 'node1', type: 'state', position: { x: 0, y: 0 } }],
            edges: [],
          },
        },
      });

      wrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: 2,
        },
      });
    });

    it('should initialize with empty history', () => {
      expect(wrapper.vm.history).toEqual([]);
      expect(wrapper.vm.currentHistoryIndex).toBe(-1);
    });

    it('should save initial state to history after loading', async () => {
      await nextTick();
      await nextTick();
      await nextTick();

      expect(wrapper.vm.history.length).toBeGreaterThan(0);
      expect(wrapper.vm.history[0].action).toBe('initial_load');
    });

    it('should have canUndo as false initially', () => {
      expect(wrapper.vm.canUndo).toBe(false);
    });

    it('should have canRedo as false initially', () => {
      expect(wrapper.vm.canRedo).toBe(false);
    });

    it('should enable undo after a change', async () => {
      await nextTick();
      await nextTick();
      await nextTick();

      // Add a node
      wrapper.vm.nodes.push({
        id: 'node2',
        type: 'intent',
        position: { x: 100, y: 100 },
      });

      wrapper.vm.saveToHistory('add_node');

      expect(wrapper.vm.canUndo).toBe(true);
    });

    it('should limit history to MAX_HISTORY entries', async () => {
      const MAX_HISTORY = 50;

      // Add many history entries
      for (let i = 0; i < MAX_HISTORY + 10; i += 1) {
        wrapper.vm.saveToHistory(`change_${i}`);
      }

      expect(wrapper.vm.history.length).toBe(MAX_HISTORY);
    });
  });

  describe('Copy/Paste/Duplicate', () => {
    beforeEach(async () => {
      mockStore.dispatch.mockResolvedValue({
        flow: {
          flow_data: {
            nodes: [
              {
                id: 'node1',
                type: 'state',
                position: { x: 0, y: 0 },
                data: { label: 'State 1' },
              },
            ],
            edges: [],
          },
        },
      });

      wrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: 2,
        },
      });

      await nextTick();
      await nextTick();
      await nextTick();
    });

    it('should copy selected nodes to clipboard', () => {
      // Mock selected nodes
      wrapper.vm.getSelectedNodes = {
        value: [
          {
            id: 'node1',
            type: 'state',
            position: { x: 0, y: 0 },
            data: { label: 'State 1' },
          },
        ],
      };

      wrapper.vm.copyNodes();

      expect(wrapper.vm.clipboard).not.toBeNull();
      expect(wrapper.vm.clipboard.nodes).toHaveLength(1);
      expect(wrapper.vm.clipboard.nodes[0].id).toBe('node1');
    });

    it('should not copy when no nodes selected', () => {
      wrapper.vm.getSelectedNodes = { value: [] };
      wrapper.vm.clipboard = null;

      wrapper.vm.copyNodes();

      expect(wrapper.vm.clipboard).toBeNull();
    });

    it('should paste nodes with offset', () => {
      const PASTE_OFFSET = 50;

      // Setup clipboard
      wrapper.vm.clipboard = {
        nodes: [
          {
            id: 'node1',
            type: 'state',
            position: { x: 0, y: 0 },
            data: { label: 'State 1' },
          },
        ],
        edges: [],
        timestamp: Date.now(),
      };

      const initialNodeCount = wrapper.vm.nodes.length;
      wrapper.vm.pasteNodes();

      expect(wrapper.vm.nodes.length).toBe(initialNodeCount + 1);

      const pastedNode = wrapper.vm.nodes[wrapper.vm.nodes.length - 1];
      expect(pastedNode.position.x).toBe(PASTE_OFFSET);
      expect(pastedNode.position.y).toBe(PASTE_OFFSET);
      expect(pastedNode.id).not.toBe('node1'); // Should have new ID
    });

    it('should duplicate selected nodes', () => {
      wrapper.vm.getSelectedNodes = {
        value: [
          {
            id: 'node1',
            type: 'state',
            position: { x: 0, y: 0 },
            data: { label: 'State 1' },
          },
        ],
      };

      const initialNodeCount = wrapper.vm.nodes.length;
      wrapper.vm.duplicateNodes();

      expect(wrapper.vm.nodes.length).toBe(initialNodeCount + 1);
    });
  });

  describe('Delete Functionality', () => {
    beforeEach(async () => {
      mockStore.dispatch.mockResolvedValue({
        flow: {
          flow_data: {
            nodes: [
              { id: 'node1', type: 'state', position: { x: 0, y: 0 } },
              { id: 'node2', type: 'intent', position: { x: 100, y: 100 } },
            ],
            edges: [{ id: 'edge1', source: 'node1', target: 'node2' }],
          },
        },
      });

      wrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: 2,
        },
      });

      await nextTick();
      await nextTick();
      await nextTick();
    });

    it('should delete selected nodes', () => {
      wrapper.vm.getSelectedNodes = {
        value: [{ id: 'node1' }],
      };
      wrapper.vm.getSelectedEdges = { value: [] };

      const initialNodeCount = wrapper.vm.nodes.length;
      wrapper.vm.deleteSelected();

      expect(wrapper.vm.nodes.length).toBeLessThan(initialNodeCount);
    });

    it('should delete selected edges', () => {
      wrapper.vm.getSelectedNodes = { value: [] };
      wrapper.vm.getSelectedEdges = {
        value: [{ id: 'edge1' }],
      };

      const initialEdgeCount = wrapper.vm.edges.length;
      wrapper.vm.deleteSelected();

      expect(wrapper.vm.edges.length).toBeLessThan(initialEdgeCount);
    });

    it('should not delete when nothing is selected', () => {
      wrapper.vm.getSelectedNodes = { value: [] };
      wrapper.vm.getSelectedEdges = { value: [] };

      const initialNodeCount = wrapper.vm.nodes.length;
      const initialEdgeCount = wrapper.vm.edges.length;

      wrapper.vm.deleteSelected();

      expect(wrapper.vm.nodes.length).toBe(initialNodeCount);
      expect(wrapper.vm.edges.length).toBe(initialEdgeCount);
    });
  });

  describe('Search Functionality', () => {
    beforeEach(async () => {
      mockStore.dispatch.mockResolvedValue({
        flow: {
          flow_data: {
            nodes: [
              {
                id: 'node1',
                type: 'state',
                position: { x: 0, y: 0 },
                data: { label: 'Start State', state_id: 'START' },
              },
              {
                id: 'node2',
                type: 'intent',
                position: { x: 100, y: 100 },
                data: { keywords: ['help', 'support'] },
              },
              {
                id: 'node3',
                type: 'template',
                position: { x: 200, y: 200 },
                data: { template_name: 'main_menu' },
              },
            ],
            edges: [],
          },
        },
      });

      wrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: 2,
        },
      });

      await nextTick();
      await nextTick();
      await nextTick();
    });

    it('should find nodes by label', () => {
      wrapper.vm.searchQuery = 'start';
      wrapper.vm.searchNodes();

      expect(wrapper.vm.highlightedNodeIds).toContain('node1');
      expect(wrapper.vm.highlightedNodeIds).toHaveLength(1);
    });

    it('should find nodes by state_id', () => {
      wrapper.vm.searchQuery = 'START';
      wrapper.vm.searchNodes();

      expect(wrapper.vm.highlightedNodeIds).toContain('node1');
    });

    it('should find nodes by keywords', () => {
      wrapper.vm.searchQuery = 'help';
      wrapper.vm.searchNodes();

      expect(wrapper.vm.highlightedNodeIds).toContain('node2');
    });

    it('should find nodes by template name', () => {
      wrapper.vm.searchQuery = 'main_menu';
      wrapper.vm.searchNodes();

      expect(wrapper.vm.highlightedNodeIds).toContain('node3');
    });

    it('should be case insensitive', () => {
      wrapper.vm.searchQuery = 'HELP';
      wrapper.vm.searchNodes();

      expect(wrapper.vm.highlightedNodeIds).toContain('node2');
    });

    it('should clear search', () => {
      wrapper.vm.searchQuery = 'help';
      wrapper.vm.searchNodes();

      expect(wrapper.vm.highlightedNodeIds.length).toBeGreaterThan(0);

      wrapper.vm.clearSearch();

      expect(wrapper.vm.searchQuery).toBe('');
      expect(wrapper.vm.highlightedNodeIds).toHaveLength(0);
    });

    it('should return empty when query is empty', () => {
      wrapper.vm.searchQuery = '';
      wrapper.vm.searchNodes();

      expect(wrapper.vm.highlightedNodeIds).toHaveLength(0);
    });
  });

  describe('Auto Layout', () => {
    beforeEach(async () => {
      mockStore.dispatch.mockResolvedValue({
        flow: {
          flow_data: {
            nodes: [
              {
                id: 'node1',
                type: 'state',
                position: { x: 500, y: 500 },
              },
              {
                id: 'node2',
                type: 'intent',
                position: { x: 800, y: 300 },
              },
              {
                id: 'node3',
                type: 'template',
                position: { x: 200, y: 700 },
              },
            ],
            edges: [],
          },
        },
      });

      wrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: 2,
        },
      });

      await nextTick();
      await nextTick();
      await nextTick();
    });

    it('should reorganize nodes by type', () => {
      wrapper.vm.autoLayout();

      const stateNodes = wrapper.vm.nodes.filter(n => n.type === 'state');
      const intentNodes = wrapper.vm.nodes.filter(n => n.type === 'intent');
      const templateNodes = wrapper.vm.nodes.filter(n => n.type === 'template');

      // State nodes should be in first row
      expect(stateNodes[0].position.y).toBe(50);

      // Intent nodes should be in second row
      if (intentNodes.length > 0) {
        expect(intentNodes[0].position.y).toBeGreaterThan(
          stateNodes[0].position.y
        );
      }

      // Template nodes should be in third row
      if (templateNodes.length > 0) {
        expect(templateNodes[0].position.y).toBeGreaterThan(
          intentNodes[0]?.position.y || 50
        );
      }
    });

    it('should space nodes horizontally', () => {
      const horizontalSpacing = 250;

      wrapper.vm.autoLayout();

      const stateNodes = wrapper.vm.nodes.filter(n => n.type === 'state');
      if (stateNodes.length > 1) {
        const spacing = stateNodes[1].position.x - stateNodes[0].position.x;
        expect(spacing).toBe(horizontalSpacing);
      }
    });

    it('should not break with empty nodes', () => {
      wrapper.vm.nodes = [];

      expect(() => wrapper.vm.autoLayout()).not.toThrow();
    });
  });

  describe('getFlowData', () => {
    it('should return current nodes and edges', async () => {
      mockStore.dispatch.mockResolvedValue({
        flow: {
          flow_data: {
            nodes: [{ id: 'node1' }],
            edges: [{ id: 'edge1' }],
          },
        },
      });

      wrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: 2,
        },
      });

      await nextTick();
      await nextTick();
      await nextTick();

      const flowData = wrapper.vm.getFlowData();

      expect(flowData).toHaveProperty('nodes');
      expect(flowData).toHaveProperty('edges');
      expect(Array.isArray(flowData.nodes)).toBe(true);
      expect(Array.isArray(flowData.edges)).toBe(true);
    });
  });

  describe('Platform Detection', () => {
    it('should detect Mac platform', () => {
      Object.defineProperty(navigator, 'platform', {
        value: 'MacIntel',
        writable: true,
      });

      wrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: null,
        },
      });

      expect(wrapper.vm.isMac).toBe(true);
    });

    it('should detect non-Mac platform', () => {
      Object.defineProperty(navigator, 'platform', {
        value: 'Win32',
        writable: true,
      });

      wrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: null,
        },
      });

      expect(wrapper.vm.isMac).toBe(false);
    });
  });

  describe('Event Emissions', () => {
    it('should emit node-selected when node is clicked', async () => {
      wrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: null,
        },
      });

      const testNode = { id: 'node1', type: 'state' };
      wrapper.vm.onNodeClick({ node: testNode });

      expect(wrapper.emitted('nodeSelected')).toBeTruthy();
      expect(wrapper.emitted('nodeSelected')[0]).toEqual([testNode]);
    });

    it('should emit compile when compileFlow is called', () => {
      wrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: null,
        },
      });

      wrapper.vm.compileFlow();

      expect(wrapper.emitted('compile')).toBeTruthy();
    });
  });

  describe('Keyboard Shortcuts', () => {
    beforeEach(async () => {
      mockStore.dispatch.mockResolvedValue({
        flow: {
          flow_data: {
            nodes: [{ id: 'node1', type: 'state', position: { x: 0, y: 0 } }],
            edges: [],
          },
        },
      });

      wrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: 2,
        },
        attachTo: document.body,
      });

      await nextTick();
      await nextTick();
      await nextTick();
    });

    afterEach(() => {
      wrapper.unmount();
    });

    it('should register keyboard event listener on mount', () => {
      const addEventListenerSpy = vi.spyOn(window, 'addEventListener');

      mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: null,
        },
      });

      expect(addEventListenerSpy).toHaveBeenCalledWith(
        'keydown',
        expect.any(Function)
      );
    });

    it('should remove keyboard event listener on unmount', () => {
      const removeEventListenerSpy = vi.spyOn(window, 'removeEventListener');

      const tempWrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: null,
        },
      });

      tempWrapper.unmount();

      expect(removeEventListenerSpy).toHaveBeenCalledWith(
        'keydown',
        expect.any(Function)
      );
    });
  });

  describe('Edge Selection', () => {
    it('should enable edge selection in interactive mode', () => {
      wrapper = mount(BotStudioCanvas, {
        props: {
          botId: 1,
          flowId: null,
        },
      });

      expect(wrapper.vm.isInteractive).toBe(true);

      const vueFlow = wrapper.findComponent(VueFlow);
      expect(vueFlow.props('edgesUpdatable')).toBe(true);
      expect(vueFlow.props('elementsSelectable')).toBe(true);
    });
  });
});
