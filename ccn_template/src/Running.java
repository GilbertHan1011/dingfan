import com.sun.org.apache.xpath.internal.NodeSet;
import node.Node;
import node.Request;
import node.Respond;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.util.*;

/**
 * Created by renfei on 16/3/30.
 */
public class Running {
    static int n = 0;
    static Map<Integer, Integer> map = new HashMap<>();

    public static void main(String[] args) throws IOException {
        float ws[] = new float[7];
        ws[0] = 1;
        createWs(ws, 1, 1f);
        System.out.println(n);

    }

    public static void init(float[] ws) {

        for (int i = 0; i < Node.DEP; i++) {
            map.put(i, 0);
        }

        Node root = new Node("Node_0_0", Node.contentNum, null, 0);
        n++;
        for (int i = 0; i < Node.contentNum; i++) {
            root.goalNum.put("interest_" + i, 1);
            root.dataMap.put("interest_" + i, "content_" + i);
            Node.content_num.put("interest_" + i, 0);
        }
        create(ws, root, 1);
    }

    public static void create(float[] ws, Node root, int dep) {
        if (dep < Node.DEP) {
            for (int i = 0; i < Node.LEAFNUM; i++) {
                int num = map.get(dep);
                map.put(dep, num + 1);
                Node tem = new Node("Node_" + dep + "_" + num, 10000, root, ws[dep]);
                Node.nodeSet.add(tem);
                n++;
                root.sonNodes.add(tem);
                create(ws, tem, dep + 1);
            }
        } else if (dep == Node.DEP) {
            root.isLeaf = true;
            Node.leavesNodes.add(root);
        }
    }

    public static void start(float[] ws) throws IOException {
        int leavesNum = Node.leavesNodes.size();
        int num = 0;
        boolean isSteady = false;
        while (num < 2000000) {
            num++;
            Request request = new Request();
            request.interest = createInteres();
//            request.interest = "interest_" + Node.random.nextInt(10000);
            Map<String, Integer> content_num = Node.content_num;
            content_num.put(request.interest, content_num.get(request.interest) + 1);
            Respond ans = Node.find(Node.leavesNodes.get(Node.random.nextInt(leavesNum)), request, isSteady);

            if (num > 1000000) {
                isSteady = true;
            }


//            if(num%10000==0)
//            {
////                seeRMP(ws, num);
//
////                System.out.println(content_num);
//            }
        }
        seeRMP(ws, num);
    }

    public static boolean isCacheFull() {
        for (Node node : Node.nodeSet) {
            if (node.capacity != node.dataMap.size()) {
                return false;
            }
        }
        return true;
    }

    public static String createInteres() {
        String ans = "interest_";
        Random rand = new Random();
//        if (rand.nextFloat() < 0.8) {
//            ans = ans + rand.nextInt(20000);
//        } else {
//            ans = ans + (rand.nextInt(80000) + 20000);
//        }
        ans = ans + rand.nextInt(100000);
        return ans;
    }

    public static void seeRMP(float[] ws, int num) throws IOException {
        Map<String, Integer> hm1 = new TreeMap<>();
        HashMap<String, Float> hm2 = new HashMap<>();
        for (Node node : Node.nodeSet) {
            String name = "level_" + node.name.split("_")[1];
            float t1 = node.request_num * 1.0f;
            float t2 = node.goal_num * 1.0f;
            float t3 = node.allPathNum;
            float ans = t2 / t1;
            if (hm1.containsKey(name)) {
                hm1.put(name, hm1.get(name) + 1);
            } else {
                hm1.put(name, 1);
            }

            if (hm2.containsKey(name)) {
                hm2.put(name, hm2.get(name) + ans);
            } else {
                hm2.put(name, ans);
            }
        }

        String tem = "";
        for (int i = 1; i <= 6; i++) {
            tem += "level_" + i + "_权重=> " + ws[i] + "  ";
        }

        System.out.print(tem + "    ");
        System.out.print("第" + num + "次模拟请求:   平均请求跳转次数 =>" + Request.allHitNum / Request.allRqquestNum + "    ");
        String tem2 = "";
        for (String name : hm1.keySet()) {
            tem2 += name + "=>" + hm2.get(name) / hm1.get(name) + "      ";
            System.out.print(name + "=>" + hm2.get(name) / hm1.get(name) + "      ");
        }

        writeRecord("ccn1", tem + "    " + "第" + num + "次模拟请求:   平均请求跳转次数 =>" + Request.allHitNum / Request.allRqquestNum + "    " + tem2);
        writeRecord("ccn1", "==================================================================================");
        System.out.println();


        Node.nodeSet.clear();
        Node.content_num.clear();
        Node.leavesNodes.clear();
        Request.allHitNum = 0;
        Request.allRqquestNum = 0;
    }

    public static void writeRecord(String fileName, String content) throws IOException {
        File file = new File("/Users/renfei/ccnData/" + fileName + ".txt");
        if (!file.exists()) {
            file.createNewFile();
        }
        FileWriter fw = new FileWriter(file.getAbsoluteFile(), true);
        BufferedWriter bw = new BufferedWriter(fw);
        bw.write(content);
        bw.write("\n");
        bw.close();
    }

    public static void createWs(float ws[], int index, float pre) throws IOException {
        if (index > 6) {
            init(ws);
            start(ws);
        } else {
            for (float i = pre; i < 3.2f; i = i + 0.3f) {
                ws[index] = i;
                createWs(ws, index + 1, i);
            }
        }
    }
}
