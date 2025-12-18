import { actions, mutations, getters, state } from '../agentBots';
import types from '../../mutation-types';
import AgentBotsAPI from '../../../../api/agentBots';
import { vi } from 'vitest';

vi.mock('../../../../api/agentBots');
vi.mock('../../utils/api');

describe('AgentBots Store Module', () => {
  describe('State', () => {
    it('should have initial state', () => {
      const initialState = state;

      expect(initialState.records).toEqual([]);
      expect(initialState.flows).toEqual([]);
      expect(initialState.uiFlags).toBeDefined();
      expect(initialState.agentBotInbox).toEqual({});
    });
  });

  describe('Getters', () => {
    describe('getBots', () => {
      it('should return all bots', () => {
        const mockState = {
          records: [
            { id: 1, name: 'Bot 1' },
            { id: 2, name: 'Bot 2' },
          ],
        };

        const result = getters.getBots(mockState);

        expect(result).toEqual(mockState.records);
      });
    });

    describe('getBot', () => {
      it('should return specific bot by id', () => {
        const mockState = {
          records: [
            { id: 1, name: 'Bot 1' },
            { id: 2, name: 'Bot 2' },
          ],
        };

        const result = getters.getBot(mockState)(1);

        expect(result).toEqual({ id: 1, name: 'Bot 1' });
      });

      it('should return empty object when bot not found', () => {
        const mockState = {
          records: [{ id: 1, name: 'Bot 1' }],
        };

        const result = getters.getBot(mockState)(999);

        expect(result).toEqual({});
      });
    });

    describe('getFlows', () => {
      it('should return all flows', () => {
        const mockState = {
          flows: [
            { id: 1, name: 'Flow 1' },
            { id: 2, name: 'Flow 2' },
          ],
        };

        const result = getters.getFlows(mockState);

        expect(result).toEqual(mockState.flows);
      });
    });

    describe('getFlow', () => {
      it('should return specific flow by id', () => {
        const mockState = {
          flows: [
            { id: 1, name: 'Flow 1' },
            { id: 2, name: 'Flow 2' },
          ],
        };

        const result = getters.getFlow(mockState)(1);

        expect(result).toEqual({ id: 1, name: 'Flow 1' });
      });

      it('should return empty object when flow not found', () => {
        const mockState = {
          flows: [{ id: 1, name: 'Flow 1' }],
        };

        const result = getters.getFlow(mockState)(999);

        expect(result).toEqual({});
      });
    });
  });

  describe('Mutations', () => {
    describe('SET_FLOWS', () => {
      it('should set flows from array', () => {
        const mockState = { flows: [] };
        const flowsArray = [
          { id: 1, name: 'Flow 1' },
          { id: 2, name: 'Flow 2' },
        ];

        mutations[types.SET_FLOWS](mockState, flowsArray);

        expect(mockState.flows).toEqual(flowsArray);
      });

      it('should extract flows from object with flows property', () => {
        const mockState = { flows: [] };
        const response = {
          flows: [
            { id: 1, name: 'Flow 1' },
            { id: 2, name: 'Flow 2' },
          ],
        };

        mutations[types.SET_FLOWS](mockState, response);

        expect(mockState.flows).toEqual(response.flows);
      });

      it('should handle empty data', () => {
        const mockState = { flows: [] };

        mutations[types.SET_FLOWS](mockState, null);

        expect(mockState.flows).toEqual([]);
      });
    });

    describe('ADD_FLOW', () => {
      it('should add flow to array', () => {
        const mockState = { flows: [{ id: 1, name: 'Flow 1' }] };
        const newFlow = { id: 2, name: 'Flow 2' };

        mutations[types.ADD_FLOW](mockState, newFlow);

        expect(mockState.flows).toHaveLength(2);
        expect(mockState.flows[1]).toEqual(newFlow);
      });

      it('should extract flow from response object', () => {
        const mockState = { flows: [] };
        const response = { flow: { id: 1, name: 'Flow 1' } };

        mutations[types.ADD_FLOW](mockState, response);

        expect(mockState.flows).toHaveLength(1);
        expect(mockState.flows[0]).toEqual(response.flow);
      });

      it('should initialize flows array if not exists', () => {
        const mockState = {};

        mutations[types.ADD_FLOW](mockState, { id: 1, name: 'Flow 1' });

        expect(Array.isArray(mockState.flows)).toBe(true);
        expect(mockState.flows).toHaveLength(1);
      });
    });

    describe('UPDATE_FLOW', () => {
      it('should update existing flow', () => {
        const mockState = {
          flows: [
            { id: 1, name: 'Flow 1', version: 1 },
            { id: 2, name: 'Flow 2', version: 1 },
          ],
        };
        const updatedFlow = { id: 1, name: 'Updated Flow 1', version: 2 };

        mutations[types.UPDATE_FLOW](mockState, updatedFlow);

        expect(mockState.flows[0]).toEqual(updatedFlow);
        expect(mockState.flows[1]).toEqual({
          id: 2,
          name: 'Flow 2',
          version: 1,
        });
      });

      it('should extract flow from response object', () => {
        const mockState = {
          flows: [{ id: 1, name: 'Flow 1', version: 1 }],
        };
        const response = {
          flow: { id: 1, name: 'Updated Flow 1', version: 2 },
        };

        mutations[types.UPDATE_FLOW](mockState, response);

        expect(mockState.flows[0]).toEqual(response.flow);
      });

      it('should add flow if not found in array', () => {
        const mockState = {
          flows: [{ id: 1, name: 'Flow 1' }],
        };
        const newFlow = { id: 2, name: 'Flow 2' };

        mutations[types.UPDATE_FLOW](mockState, newFlow);

        expect(mockState.flows).toHaveLength(2);
        expect(mockState.flows[1]).toEqual(newFlow);
      });

      it('should initialize flows array if not exists', () => {
        const mockState = {};
        const newFlow = { id: 1, name: 'Flow 1' };

        mutations[types.UPDATE_FLOW](mockState, newFlow);

        expect(Array.isArray(mockState.flows)).toBe(true);
        expect(mockState.flows).toHaveLength(1);
      });
    });

    describe('DELETE_FLOW', () => {
      it('should delete flow by id', () => {
        const mockState = {
          flows: [
            { id: 1, name: 'Flow 1' },
            { id: 2, name: 'Flow 2' },
            { id: 3, name: 'Flow 3' },
          ],
        };

        mutations[types.DELETE_FLOW](mockState, 2);

        expect(mockState.flows).toHaveLength(2);
        expect(mockState.flows.find(f => f.id === 2)).toBeUndefined();
        expect(mockState.flows.find(f => f.id === 1)).toBeDefined();
        expect(mockState.flows.find(f => f.id === 3)).toBeDefined();
      });

      it('should handle deleting non-existent flow', () => {
        const mockState = {
          flows: [{ id: 1, name: 'Flow 1' }],
        };

        mutations[types.DELETE_FLOW](mockState, 999);

        expect(mockState.flows).toHaveLength(1);
      });
    });
  });

  describe('Actions', () => {
    let commit;

    beforeEach(() => {
      commit = vi.fn();
      vi.clearAllMocks();
    });

    describe('getFlows', () => {
      it('should fetch flows successfully', async () => {
        const mockResponse = {
          data: {
            flows: [
              { id: 1, name: 'Flow 1' },
              { id: 2, name: 'Flow 2' },
            ],
          },
        };

        AgentBotsAPI.getFlows.mockResolvedValue(mockResponse);

        const result = await actions.getFlows(
          { commit },
          1 // botId
        );

        expect(AgentBotsAPI.getFlows).toHaveBeenCalledWith(1);
        expect(commit).toHaveBeenCalledWith(types.SET_AGENT_BOT_UI_FLAG, {
          isFetchingFlows: true,
        });
        expect(commit).toHaveBeenCalledWith(types.SET_FLOWS, mockResponse.data);
        expect(commit).toHaveBeenCalledWith(types.SET_AGENT_BOT_UI_FLAG, {
          isFetchingFlows: false,
        });
        expect(result).toEqual(mockResponse.data);
      });

      it('should handle errors', async () => {
        const error = new Error('API Error');
        AgentBotsAPI.getFlows.mockRejectedValue(error);

        const result = await actions.getFlows({ commit }, 1);

        expect(commit).toHaveBeenCalledWith(types.SET_AGENT_BOT_UI_FLAG, {
          isFetchingFlows: false,
        });
        expect(result).toBeNull();
      });
    });

    describe('createFlow', () => {
      it('should create flow successfully', async () => {
        const flowData = {
          name: 'New Flow',
          flow_data: { nodes: [], edges: [] },
        };
        const mockResponse = {
          data: { flow: { id: 3, ...flowData } },
        };

        AgentBotsAPI.createFlow.mockResolvedValue(mockResponse);

        const result = await actions.createFlow(
          { commit },
          { botId: 1, ...flowData }
        );

        expect(AgentBotsAPI.createFlow).toHaveBeenCalledWith(1, flowData);
        expect(commit).toHaveBeenCalledWith(types.SET_AGENT_BOT_UI_FLAG, {
          isCreatingFlow: true,
        });
        expect(commit).toHaveBeenCalledWith(types.ADD_FLOW, mockResponse.data);
        expect(commit).toHaveBeenCalledWith(types.SET_AGENT_BOT_UI_FLAG, {
          isCreatingFlow: false,
        });
        expect(result).toEqual(mockResponse.data);
      });

      it('should handle create errors', async () => {
        const error = new Error('Create failed');
        AgentBotsAPI.createFlow.mockRejectedValue(error);

        const result = await actions.createFlow(
          { commit },
          { botId: 1, name: 'New Flow' }
        );

        expect(commit).toHaveBeenCalledWith(types.SET_AGENT_BOT_UI_FLAG, {
          isCreatingFlow: false,
        });
        expect(result).toBeNull();
      });
    });

    describe('updateFlow', () => {
      it('should update flow successfully', async () => {
        const flowData = {
          flow_data: { nodes: [{ id: 'node1' }], edges: [] },
        };
        const mockResponse = {
          data: {
            flow: { id: 2, name: 'Updated Flow', ...flowData },
          },
        };

        AgentBotsAPI.updateFlow.mockResolvedValue(mockResponse);

        const result = await actions.updateFlow(
          { commit },
          { botId: 1, flowId: 2, ...flowData }
        );

        expect(AgentBotsAPI.updateFlow).toHaveBeenCalledWith(1, 2, flowData);
        expect(commit).toHaveBeenCalledWith(types.SET_AGENT_BOT_UI_FLAG, {
          isUpdatingFlow: true,
        });
        expect(commit).toHaveBeenCalledWith(
          types.UPDATE_FLOW,
          mockResponse.data
        );
        expect(commit).toHaveBeenCalledWith(types.SET_AGENT_BOT_UI_FLAG, {
          isUpdatingFlow: false,
        });
        expect(result).toEqual(mockResponse.data);
      });

      it('should handle update errors', async () => {
        const error = new Error('Update failed');
        AgentBotsAPI.updateFlow.mockRejectedValue(error);

        const result = await actions.updateFlow(
          { commit },
          { botId: 1, flowId: 2, flow_data: {} }
        );

        expect(commit).toHaveBeenCalledWith(types.SET_AGENT_BOT_UI_FLAG, {
          isUpdatingFlow: false,
        });
        expect(result).toBeNull();
      });
    });

    describe('deleteFlow', () => {
      it('should delete flow successfully', async () => {
        AgentBotsAPI.deleteFlow.mockResolvedValue({});

        const result = await actions.deleteFlow(
          { commit },
          { botId: 1, flowId: 2 }
        );

        expect(AgentBotsAPI.deleteFlow).toHaveBeenCalledWith(1, 2);
        expect(commit).toHaveBeenCalledWith(types.SET_AGENT_BOT_UI_FLAG, {
          isDeletingFlow: true,
        });
        expect(commit).toHaveBeenCalledWith(types.DELETE_FLOW, 2);
        expect(commit).toHaveBeenCalledWith(types.SET_AGENT_BOT_UI_FLAG, {
          isDeletingFlow: false,
        });
        expect(result).toBe(true);
      });

      it('should handle delete errors', async () => {
        const error = new Error('Delete failed');
        AgentBotsAPI.deleteFlow.mockRejectedValue(error);

        const result = await actions.deleteFlow(
          { commit },
          { botId: 1, flowId: 2 }
        );

        expect(commit).toHaveBeenCalledWith(types.SET_AGENT_BOT_UI_FLAG, {
          isDeletingFlow: false,
        });
        expect(result).toBe(false);
      });
    });

    describe('compileFlow', () => {
      it('should compile flow successfully', async () => {
        const mockResponse = {
          data: { success: true, bot_config: {} },
        };

        AgentBotsAPI.compileFlow.mockResolvedValue(mockResponse);

        const result = await actions.compileFlow(
          { commit },
          { botId: 1, flowId: 2 }
        );

        expect(AgentBotsAPI.compileFlow).toHaveBeenCalledWith(1, 2);
        expect(commit).toHaveBeenCalledWith(types.SET_AGENT_BOT_UI_FLAG, {
          isCompilingFlow: true,
        });
        expect(commit).toHaveBeenCalledWith(types.SET_AGENT_BOT_UI_FLAG, {
          isCompilingFlow: false,
        });
        expect(result).toEqual(mockResponse.data);
      });

      it('should handle compile errors', async () => {
        const error = new Error('Compile failed');
        AgentBotsAPI.compileFlow.mockRejectedValue(error);

        const result = await actions.compileFlow(
          { commit },
          { botId: 1, flowId: 2 }
        );

        expect(commit).toHaveBeenCalledWith(types.SET_AGENT_BOT_UI_FLAG, {
          isCompilingFlow: false,
        });
        expect(result).toBeNull();
      });
    });

    describe('getFlow', () => {
      it('should fetch single flow successfully', async () => {
        const mockResponse = {
          data: {
            flow: {
              id: 2,
              name: 'Test Flow',
              flow_data: { nodes: [], edges: [] },
            },
          },
        };

        AgentBotsAPI.getFlow.mockResolvedValue(mockResponse);

        const result = await actions.getFlow({}, { botId: 1, flowId: 2 });

        expect(AgentBotsAPI.getFlow).toHaveBeenCalledWith(1, 2);
        expect(result).toEqual(mockResponse.data);
      });

      it('should handle getFlow errors', async () => {
        const error = new Error('Flow not found');
        AgentBotsAPI.getFlow.mockRejectedValue(error);

        const result = await actions.getFlow({}, { botId: 1, flowId: 999 });

        expect(result).toBeNull();
      });
    });
  });
});
