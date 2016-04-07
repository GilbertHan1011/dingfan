package node;

import java.util.*;

/**
 * Created by renfei on 16/3/10.
 */
public class Node {
    public static Set<Node> nodeSet = new HashSet();
    public static Random random = new Random();
    public int request_num = 0;
    public int goal_num = 0;
    public static int contentNum = 100000;
    public static Map<String, Integer> content_num = new HashMap();
    public static String serverName = "Node_0_0";
    public static int DEP = 7;
    public static int LEAFNUM = 2;
    public static List<Node> leavesNodes = new ArrayList();
    public String name; //节点名
    public int capacity; //节点容量
    public Map<String, String> dataMap = new HashMap(); //模拟数据库，key为兴趣包，val为内容包
    public List<String> dataList = new ArrayList<>();
    public Map<String, Integer> goalNum = new HashMap(); //记录节点中内容的命中次数,key为兴趣包，val为命中次数
    public Node pre; //父节点
    public List<Node> sonNodes = new LinkedList(); //子节点列表
    public float p = 0.3f;
    public float weight;
    public boolean isLeaf = false;
    public float allPathNum = 0;

    public Node(String name, int capacity, Node pre, float weight) {
        this.name = name;
        this.capacity = capacity;
        this.pre = pre;
        this.weight = weight;
    }

    public static Respond find(Node root, Request request, boolean isSteady) {
        String interest = request.interest;
        List<Node> list = request.nodeList;
        list.add(0, root);
        if (isSteady) {
            root.request_num++;
        }
        if (root.dataMap.containsKey(interest)) {
            if (isSteady)
            {
                Request.allHitNum += list.size();
                root.goal_num++;
            }

            String content = root.dataMap.get(interest);
            Respond respond = new Respond();
            respond.pathLen = list.size();
            respond.interest = interest;
            respond.content = content;
            respond.pathList = list;
            Node tem = list.remove(0);
            for (Node node : list) {
                Map<String, String> dataMap = node.dataMap;
                Map<String, Integer> goalNum = node.goalNum;
                List<String> dataList = node.dataList;
                float p = node.p * node.weight;
                float x = Node.random.nextFloat();
                if (x < p && !dataMap.containsKey(interest)) {
                    int t1 = 0;
                    if (dataMap.size() >= node.capacity) {
//                        int max = 1000000000;
//                        String maxInterest = null;
//                        for (String s : goalNum.keySet()) {
//                            if (goalNum.get(s) <= max) {
//                                maxInterest = s;
//                            }
//                        }
//                        if (maxInterest != null) {
//                            dataMap.remove(maxInterest);
//                            goalNum.remove(maxInterest);
//                        }

                        int size = dataList.size();
                        t1 = Node.random.nextInt(size);
                        String inter = dataList.get(t1);
                        dataMap.remove(inter);
                        goalNum.remove(inter);
                        dataList.set(t1, inter);

                    }else{
                        dataList.add(0, interest);
                    }
                    dataMap.put(interest, content);
                    goalNum.put(interest, 0);


                }
            }
            list.add(0, tem);
            root.goalNum.put(interest, root.goalNum.get(interest) + 1);
            return respond;
        } else {
            return find(root.pre, request, isSteady);
        }
    }
}
